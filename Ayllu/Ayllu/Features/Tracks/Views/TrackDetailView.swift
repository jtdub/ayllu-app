import SwiftUI
import MapKit

/// Detail view for a completed track
struct TrackDetailView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let track: Track

    @State private var currentTrack: Track
    @State private var trackCoordinates: [CLLocationCoordinate2D] = []
    @State private var pointCount: Int = 0
    @State private var showingDeleteConfirmation = false
    @State private var showingEditName = false
    @State private var editingName = ""
    @State private var editingDescription = ""
    @State private var mapRegion: MKCoordinateRegion?

    init(track: Track) {
        self.track = track
        _currentTrack = State(initialValue: track)
        _editingName = State(initialValue: track.name)
        _editingDescription = State(initialValue: track.description ?? "")
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map with track polyline
                if !trackCoordinates.isEmpty, let region = mapRegion {
                    mapView(region: region)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Statistics
                TrackStatisticsView(
                    track: currentTrack,
                    pointCount: pointCount
                )
                .padding(.horizontal)

                // Track metadata
                metadataSection
                    .padding(.horizontal)

                // Actions
                actionButtons
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(currentTrack.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditName = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
                    }

                    Button {
                        // TODO: Implement GPX export
                    } label: {
                        Label("Export GPX", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadTrackData()
        }
        .alert("Edit Track", isPresented: $showingEditName) {
            TextField("Name", text: $editingName)
            TextField("Description", text: $editingDescription)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveChanges()
            }
        }
        .alert("Delete Track?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteTrack()
            }
        } message: {
            Text("This will permanently delete the track and all its points.")
        }
    }

    // MARK: - Map View

    private func mapView(region: MKCoordinateRegion) -> some View {
        Map(initialPosition: .region(region)) {
            // Track polyline
            MapPolyline(coordinates: trackCoordinates)
                .stroke(.blue, lineWidth: 3)

            // Start marker
            if let start = trackCoordinates.first {
                Marker("Start", coordinate: start)
                    .tint(.green)
            }

            // End marker
            if let end = trackCoordinates.last {
                Marker("End", coordinate: end)
                    .tint(.red)
            }
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Name", value: currentTrack.name)
                    .font(.subheadline)

                if let description = currentTrack.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(description)
                            .font(.subheadline)
                    }
                }

                LabeledContent("Started", value: dateFormatter.string(from: currentTrack.startTime))
                    .font(.subheadline)

                if let endTime = currentTrack.endTime {
                    LabeledContent("Ended", value: dateFormatter.string(from: endTime))
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                openInMaps()
            } label: {
                Label("View in Maps", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                shareTrack()
            } label: {
                Label("Share Track", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func loadTrackData() {
        guard let trackId = track.id else { return }
        let repo = TrackRepository(dbPool: database.dbPool)

        do {
            // Load simplified coordinates for performance
            trackCoordinates = try repo.fetchSimplifiedCoordinates(trackId: trackId, tolerance: 10.0)
            pointCount = try repo.countTrackPoints(trackId: trackId)

            // Calculate map region
            if !trackCoordinates.isEmpty {
                calculateMapRegion()
            }
        } catch {
            // Handle error silently
        }
    }

    private func calculateMapRegion() {
        guard !trackCoordinates.isEmpty else { return }

        var minLat = trackCoordinates[0].latitude
        var maxLat = trackCoordinates[0].latitude
        var minLon = trackCoordinates[0].longitude
        var maxLon = trackCoordinates[0].longitude

        for coord in trackCoordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,  // Add 20% padding
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        mapRegion = MKCoordinateRegion(center: center, span: span)
    }

    private func saveChanges() {
        guard let trackId = currentTrack.id else { return }
        let repo = TrackRepository(dbPool: database.dbPool)

        var updated = currentTrack
        updated.name = editingName
        updated.description = editingDescription.isEmpty ? nil : editingDescription

        do {
            currentTrack = try repo.updateTrack(updated)
        } catch {
            // Handle error silently
        }
    }

    private func deleteTrack() {
        guard let trackId = currentTrack.id else { return }
        let repo = TrackRepository(dbPool: database.dbPool)

        do {
            try repo.deleteTrack(id: trackId)
            dismiss()
        } catch {
            // Handle error silently
        }
    }

    private func openInMaps() {
        guard let start = trackCoordinates.first else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: start))
        mapItem.name = currentTrack.name
        mapItem.openInMaps()
    }

    private func shareTrack() {
        // TODO: Implement GPX export and sharing
    }
}

#Preview {
    NavigationStack {
        TrackDetailView(track: Track(
            id: 1,
            projectId: 1,
            name: "Morning Hike",
            startTime: Date().addingTimeInterval(-7_200),
            endTime: Date().addingTimeInterval(-3_600),
            distance: 5_234,
            duration: 3_600,
            elevationGain: 234,
            elevationLoss: 189
        ))
    }
}
