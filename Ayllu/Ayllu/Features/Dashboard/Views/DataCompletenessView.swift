import SwiftUI

/// Dashboard showing data completeness metrics for a project
struct DataCompletenessView: View {
    @Environment(DatabaseManager.self) private var database

    let projectId: Int64

    @State private var viewModel: DataCompletenessViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    ProgressView()
                } else if let completeness = viewModel.completeness {
                    completenessContent(completeness, viewModel: viewModel)
                } else if let error = viewModel.error {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Data Completeness")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = DataCompletenessViewModel(
                    dbPool: database.dbPool,
                    projectId: projectId
                )
            }
            viewModel?.load()
        }
    }

    @ViewBuilder
    private func completenessContent(
        _ completeness: ProjectCompleteness,
        viewModel: DataCompletenessViewModel
    ) -> some View {
        List {
            // Overview card
            Section {
                HStack(spacing: 20) {
                    CompletenessRingView(value: completeness.completionPercentage)

                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Total Records") {
                            Text("\(completeness.totalRecords)")
                                .fontWeight(.semibold)
                        }
                        LabeledContent("Complete") {
                            Text("\(completeness.completeCount)")
                                .foregroundStyle(.green)
                        }
                        if completeness.draftCount > 0 {
                            LabeledContent("Drafts") {
                                Text("\(completeness.draftCount)")
                                    .foregroundStyle(.orange)
                            }
                        }
                        if completeness.incompleteCount > 0 {
                            LabeledContent("Incomplete") {
                                Text("\(completeness.incompleteCount)")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 8)
            }

            // Per-type breakdown
            if !completeness.typeCompleteness.isEmpty {
                Section("By Record Type") {
                    ForEach(completeness.typeCompleteness) { typeComp in
                        typeRow(typeComp, viewModel: viewModel)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func typeRow(
        _ typeComp: RecordTypeCompleteness,
        viewModel: DataCompletenessViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.toggleExpanded(typeComp.recordType.id)
            } label: {
                HStack {
                    Image(systemName: typeComp.recordType.iconName ?? "doc")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(typeComp.recordType.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(typeComp.completeCount)/\(typeComp.totalCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        CompletenessProgressBar(value: typeComp.completionPercentage)
                    }

                    if !typeComp.incompleteRecords.isEmpty {
                        Image(
                            systemName: viewModel.expandedTypeId == typeComp.recordType.id
                                ? "chevron.down" : "chevron.right"
                        )
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded incomplete records
            if viewModel.expandedTypeId == typeComp.recordType.id {
                ForEach(typeComp.incompleteRecords) { incomplete in
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                            .font(.caption)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(incomplete.record.name)
                                .font(.subheadline)
                            Text("Missing: \(incomplete.missingFields.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 32)
                }
            }
        }
    }
}
