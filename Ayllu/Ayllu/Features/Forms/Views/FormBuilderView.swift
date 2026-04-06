import SwiftUI

/// View for building a form template by adding, editing, and reordering fields
struct FormBuilderView: View {
    @Environment(DatabaseManager.self) private var database

    let recordTypeId: Int64

    @State private var viewModel: FormBuilderViewModel?
    @State private var showingAddField = false
    @State private var editingField: FormField?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.fields.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Form Fields",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add fields to define what data to collect for this record type.")
                    )
                } else {
                    List {
                        ForEach(viewModel.fields) { field in
                            FieldRow(field: field)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingField = field
                                }
                        }
                        .onMove { source, destination in
                            viewModel.moveFields(from: source, to: destination)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteField(viewModel.fields[index])
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Form Builder")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddField = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddField) {
            NavigationStack {
                if let viewModel {
                    FieldEditorView(viewModel: viewModel)
                }
            }
        }
        .sheet(item: $editingField) { field in
            NavigationStack {
                if let viewModel {
                    FieldEditorView(viewModel: viewModel, existingField: field)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = FormBuilderViewModel(dbPool: database.dbPool, recordTypeId: recordTypeId)
            }
            viewModel?.loadTemplate()
        }
    }
}

// MARK: - Field Row

private struct FieldRow: View {
    let field: FormField

    var body: some View {
        HStack {
            Image(systemName: field.fieldType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(field.label)
                        .font(.headline)

                    if field.isRequired {
                        Text("Required")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(field.fieldType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
