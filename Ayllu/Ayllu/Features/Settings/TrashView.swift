import SwiftUI

/// View for managing Recently Deleted items
struct TrashView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DatabaseManager.self) private var database

    @State private var trashService: TrashService?
    @State private var deletedProjects: [Project] = []
    @State private var deletedWaypoints: [Waypoint] = []
    @State private var deletedNotes: [FieldNote] = []
    @State private var showingPurgeConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    ContentUnavailableView(
                        "No Deleted Items",
                        systemImage: "trash",
                        description: Text("Deleted items appear here for 30 days before being permanently removed")
                    )
                } else {
                    List {
                        if !deletedProjects.isEmpty {
                            Section("Projects") {
                                ForEach(deletedProjects) { project in
                                    TrashItemRow(
                                        title: project.name,
                                        subtitle: project.description,
                                        deletedAt: project.deletedAt,
                                        onRestore: { restoreProject(project) },
                                        onPermanentDelete: { permanentlyDeleteProject(project) }
                                    )
                                }
                            }
                        }

                        if !deletedWaypoints.isEmpty {
                            Section("Waypoints") {
                                ForEach(deletedWaypoints) { waypoint in
                                    TrashItemRow(
                                        title: waypoint.name,
                                        subtitle: waypoint.description,
                                        deletedAt: waypoint.deletedAt,
                                        onRestore: { restoreWaypoint(waypoint) },
                                        onPermanentDelete: { permanentlyDeleteWaypoint(waypoint) }
                                    )
                                }
                            }
                        }

                        if !deletedNotes.isEmpty {
                            Section("Notes") {
                                ForEach(deletedNotes) { note in
                                    TrashItemRow(
                                        title: note.title,
                                        subtitle: note.content,
                                        deletedAt: note.deletedAt,
                                        onRestore: { restoreNote(note) },
                                        onPermanentDelete: { permanentlyDeleteNote(note) }
                                    )
                                }
                            }
                        }

                        Section {
                            Text("""
                                Items in trash are automatically deleted after 30 days. \
                                You can restore or permanently delete them at any time.
                                """)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Empty Trash", role: .destructive) {
                            showingPurgeConfirmation = true
                        }
                    }
                }
            }
            .onAppear {
                setupService()
                loadDeletedItems()
            }
            .alert("Empty Trash?", isPresented: $showingPurgeConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Empty", role: .destructive) {
                    purgeAllDeletedItems()
                }
            } message: {
                Text("This will permanently delete all items in trash. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isEmpty: Bool {
        deletedProjects.isEmpty && deletedWaypoints.isEmpty && deletedNotes.isEmpty
    }

    private func setupService() {
        if trashService == nil {
            trashService = TrashService(dbPool: database.dbPool)
        }
    }

    private func loadDeletedItems() {
        guard let service = trashService else { return }

        do {
            deletedProjects = try service.fetchDeletedProjects()
            deletedWaypoints = try service.fetchDeletedWaypoints()
            deletedNotes = try service.fetchDeletedNotes()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // MARK: - Restore Actions

    private func restoreProject(_ project: Project) {
        guard let service = trashService else { return }
        do {
            try service.restoreProject(project)
            loadDeletedItems()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func restoreWaypoint(_ waypoint: Waypoint) {
        guard let service = trashService else { return }
        do {
            try service.restoreWaypoint(waypoint)
            loadDeletedItems()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func restoreNote(_ note: FieldNote) {
        guard let service = trashService else { return }
        do {
            try service.restoreNote(note)
            loadDeletedItems()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // MARK: - Permanent Delete Actions

    private func permanentlyDeleteProject(_ project: Project) {
        guard let service = trashService else { return }
        do {
            try service.permanentlyDeleteProject(project)
            loadDeletedItems()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func permanentlyDeleteWaypoint(_ waypoint: Waypoint) {
        guard let service = trashService else { return }
        do {
            try service.permanentlyDeleteWaypoint(waypoint)
            loadDeletedItems()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func permanentlyDeleteNote(_ note: FieldNote) {
        guard let service = trashService else { return }
        do {
            try service.permanentlyDeleteNote(note)
            loadDeletedItems()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // MARK: - Purge All

    private func purgeAllDeletedItems() {
        guard let service = trashService else { return }
        do {
            for project in deletedProjects {
                try service.permanentlyDeleteProject(project)
            }
            for waypoint in deletedWaypoints {
                try service.permanentlyDeleteWaypoint(waypoint)
            }
            for note in deletedNotes {
                try service.permanentlyDeleteNote(note)
            }
            loadDeletedItems()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Trash Item Row

struct TrashItemRow: View {
    let title: String
    let subtitle: String?
    let deletedAt: Date?
    let onRestore: () -> Void
    let onPermanentDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let deletedAt = deletedAt {
                Text("Deleted \(deletedAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onPermanentDelete()
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }

            Button {
                onRestore()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
    }
}

#Preview {
    TrashView()
}
