import SwiftUI

/// Hierarchical record browser with breadcrumb navigation
struct RecordTreeView: View {
    @Environment(DatabaseManager.self) private var database

    let projectId: Int64

    @State private var viewModel: RecordHierarchyViewModel?
    @State private var showingAddRecord = false
    @State private var selectedRecord: Record?

    var body: some View {
        Group {
            if let viewModel {
                VStack(spacing: 0) {
                    // Breadcrumb bar
                    if !viewModel.breadcrumbs.isEmpty {
                        BreadcrumbView(
                            breadcrumbs: viewModel.breadcrumbs,
                            onTapRoot: { viewModel.loadInitial() },
                            onTapBreadcrumb: { index in viewModel.navigateToBreadcrumb(at: index) }
                        )
                        Divider()
                    }

                    // Record list
                    if viewModel.currentRecords.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView(
                            viewModel.breadcrumbs.isEmpty ? "No Records" : "No Child Records",
                            systemImage: "rectangle.stack",
                            description: Text("Tap + to create a new record.")
                        )
                    } else {
                        List {
                            ForEach(viewModel.currentRecords) { record in
                                RecordTreeRow(record: record, viewModel: viewModel)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        let childCount = viewModel.childCount(for: record)
                                        if childCount > 0 {
                                            viewModel.navigateToRecord(record)
                                        } else {
                                            selectedRecord = record
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            viewModel.deleteRecord(record)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Records")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRecord = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            if let viewModel {
                NavigationStack {
                    RecordFormView(
                        projectId: projectId,
                        parentRecordId: viewModel.currentParent?.id,
                        dbPool: database.dbPool
                    ) {
                        if let parent = viewModel.currentParent, let parentId = parent.id {
                            let repo = RecordRepository(dbPool: database.dbPool)
                            viewModel.currentRecords = (try? repo.fetchChildren(parentRecordId: parentId)) ?? []
                        } else {
                            viewModel.loadInitial()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedRecord) { record in
            NavigationStack {
                RecordDetailView(record: record, dbPool: database.dbPool)
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RecordHierarchyViewModel(dbPool: database.dbPool, projectId: projectId)
            }
            viewModel?.loadInitial()
        }
    }
}

// MARK: - Record Tree Row

private struct RecordTreeRow: View {
    let record: Record
    let viewModel: RecordHierarchyViewModel

    var body: some View {
        HStack {
            Image(systemName: viewModel.recordTypeIcon(for: record))
                .foregroundStyle(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.headline)

                Text(viewModel.recordTypeName(for: record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let childCount = viewModel.childCount(for: record)
            if childCount > 0 {
                Text("\(childCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
