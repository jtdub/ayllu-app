import SwiftUI

struct ProjectPickerView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let onProjectSelected: (Int64) -> Void

    @State private var projects: [Project] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Create a project first to add notes")
                    )
                } else {
                    List(projects) { project in
                        Button {
                            if let id = project.id {
                                onProjectSelected(id)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.headline)

                                if let description = project.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadProjects()
            }
        }
    }

    private func loadProjects() {
        isLoading = true
        let repo = ProjectRepository(dbPool: database.dbPool)
        do {
            projects = try repo.fetchAll()
        } catch {
            projects = []
        }
        isLoading = false
    }
}
