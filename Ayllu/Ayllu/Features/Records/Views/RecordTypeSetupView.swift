import SwiftUI

/// View for managing record types within a project
struct RecordTypeSetupView: View {
    @Environment(DatabaseManager.self) private var database

    let projectId: Int64

    @State private var viewModel: RecordTypeListViewModel?
    @State private var showingAddType = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.recordTypes.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Record Types",
                        systemImage: "rectangle.stack",
                        description: Text("Create record types to define your data hierarchy.")
                    )
                } else {
                    List {
                        ForEach(viewModel.recordTypes) { recordType in
                            NavigationLink {
                                RecordTypeFormView(
                                    projectId: projectId,
                                    existingRecordType: recordType
                                )
                            } label: {
                                RecordTypeRow(recordType: recordType, viewModel: viewModel)
                            }
                        }
                        .onMove { source, destination in
                            viewModel.moveRecordTypes(from: source, to: destination)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteRecordType(viewModel.recordTypes[index])
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Record Types")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddType = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(
            isPresented: $showingAddType,
            onDismiss: { viewModel?.loadRecordTypes() },
            content: {
                NavigationStack {
                    RecordTypeFormView(projectId: projectId)
                }
            }
        )
        .onAppear {
            if viewModel == nil {
                viewModel = RecordTypeListViewModel(dbPool: database.dbPool, projectId: projectId)
            }
            viewModel?.loadRecordTypes()
        }
    }
}

// MARK: - Record Type Row

private struct RecordTypeRow: View {
    let recordType: RecordType
    let viewModel: RecordTypeListViewModel

    var body: some View {
        HStack {
            Image(systemName: recordType.iconName ?? "doc")
                .foregroundStyle(Color(hex: recordType.color) ?? .accentColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(recordType.name)
                    .font(.headline)

                if let description = recordType.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let parentTypeId = recordType.parentTypeId,
                   let parentType = viewModel.recordTypes.first(where: { $0.id == parentTypeId }) {
                    Text("Child of \(parentType.name)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
