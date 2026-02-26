import SwiftUI

/// Detail view for a single project
struct ProjectDetailView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let project: Project

    @State private var statistics: ProjectStatistics?
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPhotoCapture = false
    @State private var showingTrackRecording = false
    @State private var currentProject: Project

    init(project: Project) {
        self.project = project
        _currentProject = State(initialValue: project)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        List {
            // Project Info Section
            Section("Project Information") {
                LabeledContent("Name", value: currentProject.name)

                if let description = currentProject.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(description)
                    }
                }

                if let startDate = currentProject.startDate {
                    LabeledContent("Start Date", value: dateFormatter.string(from: startDate))
                }

                if let endDate = currentProject.endDate {
                    LabeledContent("End Date", value: dateFormatter.string(from: endDate))
                }
            }

            // Statistics Section
            if let stats = statistics {
                Section("Statistics") {
                    NavigationLink {
                        WaypointListView(projectId: project.id)
                    } label: {
                        Label("\(stats.waypointCount) Waypoints", systemImage: "mappin")
                    }

                    NavigationLink {
                        NoteListView(projectId: project.id)
                    } label: {
                        Label("\(stats.noteCount) Notes", systemImage: "note.text")
                    }

                    NavigationLink {
                        PhotoListView(projectId: project.id)
                    } label: {
                        Label("\(stats.photoCount) Photos", systemImage: "photo")
                    }

                    NavigationLink {
                        TrackListView(projectId: project.id)
                    } label: {
                        Label("\(stats.trackCount) Tracks", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                }
            }

            // Actions Section
            Section {
                Button {
                    showingPhotoCapture = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                Button {
                    showingTrackRecording = true
                } label: {
                    Label("Record GPS Track", systemImage: "location.circle")
                }

                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Project", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Project", systemImage: "trash")
                }
            }
        }
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadStatistics()
        }
        .sheet(isPresented: $showingPhotoCapture) {
            if let projectId = project.id {
                NavigationStack {
                    PhotoCaptureView(projectId: projectId)
                }
            }
        }
        .fullScreenCover(isPresented: $showingTrackRecording) {
            if let projectId = project.id {
                NavigationStack {
                    TrackRecordingView(projectId: projectId)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ProjectFormView(mode: .edit(currentProject)) { name, description, startDate, endDate in
                updateProject(name: name, description: description, startDate: startDate, endDate: endDate)
            }
        }
        .alert("Delete Project?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteProject()
            }
        } message: {
            Text("""
                This will permanently delete the project and all its waypoints, notes, and photos. \
                This action cannot be undone.
                """)
        }
    }

    private func loadStatistics() {
        guard let id = project.id else { return }
        let repo = ProjectRepository(dbPool: database.dbPool)
        statistics = try? repo.statistics(for: id)
    }

    private func updateProject(name: String, description: String?, startDate: Date?, endDate: Date?) {
        var updated = currentProject
        updated.name = name
        updated.description = description
        updated.startDate = startDate
        updated.endDate = endDate

        let repo = ProjectRepository(dbPool: database.dbPool)
        if let result = try? repo.update(updated) {
            currentProject = result
        }
    }

    private func deleteProject() {
        guard let id = project.id else { return }
        let repo = ProjectRepository(dbPool: database.dbPool)
        try? repo.delete(id: id)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(
            id: 1,
            name: "Test Project",
            description: "A test project for development",
            startDate: Date()
        ))
    }
}
