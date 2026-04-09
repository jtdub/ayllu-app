import SwiftUI

/// List view for GPS tracks
struct TrackListView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(TrackRecordingService.self) private var recordingService

    let projectId: Int64?

    @State private var tracks: [Track] = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateDescending
    @State private var isLoading = false
    @State private var showingRecordingView = false
    @State private var showingDeleteConfirmation = false
    @State private var trackToDelete: Track?

    init(projectId: Int64? = nil) {
        self.projectId = projectId
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if tracks.isEmpty {
                ContentUnavailableView(
                    "No Tracks",
                    systemImage: "figure.walk",
                    description: Text("Record a GPS track to get started")
                )
            } else if filteredTracks.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(filteredTracks) { track in
                        NavigationLink {
                            TrackDetailView(track: track)
                        } label: {
                            TrackRowView(track: track)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                confirmDelete(track)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Tracks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingRecordingView = true
                    } label: {
                        Label("Record Track", systemImage: "plus")
                    }

                    Divider()

                    Menu("Sort By") {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    Text(option.displayName)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingRecordingView = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search tracks")
        .onAppear {
            loadTracks()
        }
        .sheet(
            isPresented: $showingRecordingView,
            onDismiss: {
                loadTracks()
            },
            content: {
                if let projectId = projectId {
                    NavigationStack {
                        TrackRecordingView(projectId: projectId)
                    }
                }
            }
        )
        .alert("Delete Track?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let track = trackToDelete {
                    deleteTrack(track)
                }
            }
        } message: {
            Text("This will permanently delete the track and all its points.")
        }
    }

    // MARK: - Computed Properties

    private var filteredTracks: [Track] {
        var result = tracks

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { track in
                track.name.localizedCaseInsensitiveContains(searchText) ||
                (track.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Sort
        switch sortOption {
        case .dateDescending:
            result.sort { $0.startTime > $1.startTime }
        case .dateAscending:
            result.sort { $0.startTime < $1.startTime }
        case .distanceDescending:
            result.sort { ($0.distance ?? 0) > ($1.distance ?? 0) }
        case .durationDescending:
            result.sort { ($0.duration ?? 0) > ($1.duration ?? 0) }
        }

        return result
    }

    // MARK: - Actions

    private func loadTracks() {
        isLoading = true
        let repo = TrackRepository(dbPool: database.dbPool)

        do {
            tracks = try repo.fetchAllTracks(projectId: projectId)
        } catch {
            // Handle error silently for now
            tracks = []
        }

        isLoading = false
    }

    private func deleteTrack(_ track: Track) {
        guard let id = track.id else { return }
        let repo = TrackRepository(dbPool: database.dbPool)

        do {
            try repo.deleteTrack(id: id)
            withAnimation {
                tracks.removeAll { $0.id == id }
            }
        } catch {
            // Handle error silently
        }
    }

    private func confirmDelete(_ track: Track) {
        trackToDelete = track
        showingDeleteConfirmation = true
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case distanceDescending = "Longest Distance"
    case durationDescending = "Longest Duration"

    var displayName: String {
        rawValue
    }
}

#Preview {
    NavigationStack {
        TrackListView(projectId: 1)
    }
}
