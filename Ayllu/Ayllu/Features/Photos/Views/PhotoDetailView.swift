import SwiftUI
import MapKit

/// Detail view for a single photo with full-screen viewing
struct PhotoDetailView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let photo: Photo

    @State private var currentPhoto: Photo
    @State private var showingDeleteConfirmation = false
    @State private var showingEditCaption = false
    @State private var editingCaption = ""
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    init(photo: Photo) {
        self.photo = photo
        _currentPhoto = State(initialValue: photo)
        _editingCaption = State(initialValue: photo.caption ?? "")
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Full-screen photo with pinch-to-zoom
                photoView
                    .frame(maxHeight: 500)

                // Photo details
                VStack(alignment: .leading, spacing: 16) {
                    // Caption section
                    captionSection

                    // Location section
                    if currentPhoto.hasLocation {
                        locationSection
                    }

                    // Metadata section
                    metadataSection

                    // Actions
                    actionButtons
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditCaption = true
                    } label: {
                        Label("Edit Caption", systemImage: "text.bubble")
                    }

                    if currentPhoto.hasLocation {
                        Button {
                            shareLocation()
                        } label: {
                            Label("Share Location", systemImage: "square.and.arrow.up")
                        }
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
        .alert("Edit Caption", isPresented: $showingEditCaption) {
            TextField("Caption", text: $editingCaption)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveCaption()
            }
        }
        .alert("Delete Photo?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("This will permanently delete the photo and its files.")
        }
    }

    // MARK: - Photo View

    private var photoView: some View {
        Group {
            if let fileURL = currentPhoto.fileURL {
                AsyncImage(url: fileURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        // Reset if too small or too large
                                        if scale < 1.0 {
                                            withAnimation {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        } else if scale > 5.0 {
                                            withAnimation {
                                                scale = 5.0
                                                lastScale = 5.0
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                    } else {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                            }
                    case .failure:
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Failed to load photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Photo not available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            }
        }
    }

    // MARK: - Caption Section

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption")
                .font(.headline)

            if let caption = currentPhoto.caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
            } else {
                Text("No caption")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)

            if let coordinate = currentPhoto.coordinate {
                // Map preview
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker("Photo Location", coordinate: coordinate)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Coordinates
                VStack(alignment: .leading, spacing: 4) {
                    Text(CoordinateFormatter.format(
                        latitude: currentPhoto.latitude ?? 0,
                        longitude: currentPhoto.longitude ?? 0,
                        format: .decimal
                    ))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                    if let altitude = currentPhoto.altitude {
                        Text("Altitude: \(CoordinateFormatter.formatAltitude(altitude, unit: .meters))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let heading = currentPhoto.heading {
                        Text("Heading: \(String(format: "%.0f°", heading))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Taken", value: dateFormatter.string(from: currentPhoto.timestamp))
                    .font(.caption)

                if currentPhoto.waypointId != nil {
                    LabeledContent("Linked to Waypoint") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if currentPhoto.hasLocation {
                Button {
                    openInMaps()
                } label: {
                    Label("Open in Maps", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                sharePhoto()
            } label: {
                Label("Share Photo", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func saveCaption() {
        guard let photoId = currentPhoto.id else { return }
        let repo = PhotoRepository(dbPool: database.dbPool)

        do {
            try repo.updateCaption(photoId: photoId, caption: editingCaption.isEmpty ? nil : editingCaption)
            currentPhoto.caption = editingCaption.isEmpty ? nil : editingCaption
        } catch {
            // Handle error silently for now
        }
    }

    private func deletePhoto() {
        guard let photoId = currentPhoto.id else { return }
        let repo = PhotoRepository(dbPool: database.dbPool)

        do {
            try repo.deleteWithCleanup(id: photoId)
            dismiss()
        } catch {
            // Handle error silently for now
        }
    }

    private func shareLocation() {
        guard let coordinate = currentPhoto.coordinate else { return }
        let urlString = "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)"
        if let url = URL(string: urlString) {
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    private func openInMaps() {
        guard let coordinate = currentPhoto.coordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = "Photo Location"
        mapItem.openInMaps()
    }

    private func sharePhoto() {
        guard let fileURL = currentPhoto.fileURL else { return }
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    NavigationStack {
        PhotoDetailView(photo: Photo(
            id: 1,
            projectId: 1,
            filePath: "/path/to/photo.jpg",
            caption: "Test photo caption",
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 50.0
        ))
    }
}
