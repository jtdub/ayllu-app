import SwiftUI
import MapLibre
import CoreLocation

// MARK: - MLNCoordinateBounds Equatable Extension

extension MLNCoordinateBounds: @retroactive Equatable {
    public static func == (lhs: MLNCoordinateBounds, rhs: MLNCoordinateBounds) -> Bool {
        lhs.sw.latitude == rhs.sw.latitude &&
        lhs.sw.longitude == rhs.sw.longitude &&
        lhs.ne.latitude == rhs.ne.latitude &&
        lhs.ne.longitude == rhs.ne.longitude
    }
}

/// View for managing offline map regions
struct OfflineRegionManagerView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    @State private var offlineService = OfflineMapService()
    @State private var regions: [MapRegion] = []
    @State private var totalStorageUsed: String = "Calculating..."
    @State private var isLoading = false
    @State private var showingDownloadSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Storage Used", systemImage: "internaldrive")
                        Spacer()
                        Text(totalStorageUsed)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Downloaded Regions") {
                    if regions.isEmpty {
                        ContentUnavailableView(
                            "No Offline Maps",
                            systemImage: "map",
                            description: Text("Download map regions for offline use")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(regions) { region in
                            RegionRowView(
                                region: region,
                                onPause: { pauseRegion(region) },
                                onResume: { resumeRegion(region) }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteRegion(region)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Offline Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingDownloadSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadRegions()
            }
            .sheet(isPresented: $showingDownloadSheet) {
                DownloadRegionView(offlineService: offlineService) {
                    loadRegions()
                }
            }
        }
    }

    private func loadRegions() {
        isLoading = true
        let repo = MapRegionRepository(dbPool: database.dbPool)
        regions = (try? repo.fetchAll()) ?? []
        totalStorageUsed = (try? repo.formattedStorageUsed()) ?? "—"

        // Also get storage from MapLibre
        let mapLibreStorage = offlineService.calculateStorageUsed()
        if mapLibreStorage > 0 {
            totalStorageUsed = ByteCountFormatter.string(
                fromByteCount: mapLibreStorage,
                countStyle: .file
            )
        }

        isLoading = false
    }

    private func pauseRegion(_ region: MapRegion) {
        guard let id = region.id else { return }
        offlineService.pauseDownload(regionId: String(id))

        var updated = region
        updated.status = .paused
        let repo = MapRegionRepository(dbPool: database.dbPool)
        _ = try? repo.update(updated)
        loadRegions()
    }

    private func resumeRegion(_ region: MapRegion) {
        guard let id = region.id else { return }
        offlineService.resumeDownload(regionId: String(id))

        var updated = region
        updated.status = .downloading
        let repo = MapRegionRepository(dbPool: database.dbPool)
        _ = try? repo.update(updated)
        loadRegions()
    }

    private func deleteRegion(_ region: MapRegion) {
        guard let id = region.id else { return }

        // Delete from MapLibre
        try? offlineService.deleteRegion(regionId: String(id))

        // Delete from database
        let repo = MapRegionRepository(dbPool: database.dbPool)
        try? repo.delete(id: id)
        regions.removeAll { $0.id == id }
        totalStorageUsed = (try? repo.formattedStorageUsed()) ?? "—"
    }
}

// MARK: - Region Row

struct RegionRowView: View {
    let region: MapRegion
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(region.name)
                    .font(.headline)

                Spacer()

                StatusBadge(status: region.status)
            }

            if let description = region.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Zoom \(region.minZoom)-\(region.maxZoom)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(region.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if region.status == .downloading {
                HStack {
                    ProgressView(value: region.downloadProgress)
                        .tint(.blue)

                    Button {
                        onPause?()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            } else if region.status == .paused {
                HStack {
                    ProgressView(value: region.downloadProgress)
                        .tint(.orange)

                    Button {
                        onResume?()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: DownloadStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
            Text(status.displayName)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.2))
        .foregroundStyle(backgroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .complete: return .green
        case .downloading: return .blue
        case .pending: return .gray
        case .paused: return .orange
        case .failed: return .red
        }
    }
}

// MARK: - Download Region View

struct DownloadRegionView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let offlineService: OfflineMapService
    var onDownloadStarted: (() -> Void)?

    @State private var name = ""
    @State private var description = ""
    @State private var minZoom = 10
    @State private var maxZoom = 16
    @State private var estimatedTiles: Int64 = 0
    @State private var mapBounds: MLNCoordinateBounds?
    @State private var showingMap = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Region Details") {
                    TextField("Region Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }

                Section("Zoom Levels") {
                    Stepper("Min Zoom: \(minZoom)", value: $minZoom, in: 1...17)
                    Stepper("Max Zoom: \(maxZoom)", value: $maxZoom, in: minZoom...17)

                    if estimatedTiles > 0 {
                        HStack {
                            Text("Estimated tiles")
                            Spacer()
                            Text("\(estimatedTiles)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Estimated size")
                            Spacer()
                            Text(estimatedSizeString)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Select Area") {
                    if let bounds = mapBounds {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected area:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(boundsDescription(bounds))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button {
                        showingMap = true
                    } label: {
                        Label(
                            mapBounds == nil ? "Select on Map" : "Change Selection",
                            systemImage: "map"
                        )
                    }
                }

                Section {
                    Text("""
                        Higher zoom levels provide more detail but require more storage. \
                        Zoom 16 is typically sufficient for field work.
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Download Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        startDownload()
                    }
                    .disabled(name.isEmpty || mapBounds == nil)
                }
            }
            .sheet(isPresented: $showingMap) {
                RegionSelectionMapView(selectedBounds: $mapBounds)
            }
            .onChange(of: mapBounds) { _, newBounds in
                if let bounds = newBounds {
                    estimatedTiles = offlineService.estimateTileCount(
                        bounds: bounds,
                        minZoom: minZoom,
                        maxZoom: maxZoom
                    )
                }
            }
            .onChange(of: minZoom) { _, _ in
                updateTileEstimate()
            }
            .onChange(of: maxZoom) { _, _ in
                updateTileEstimate()
            }
        }
    }

    private var estimatedSizeString: String {
        // Rough estimate: ~15KB per tile on average
        let estimatedBytes = estimatedTiles * 15_000
        return ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
    }

    private func boundsDescription(_ bounds: MLNCoordinateBounds) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 4

        let sw = bounds.sw
        let ne = bounds.ne

        return "SW: \(formatter.string(from: NSNumber(value: sw.latitude))!), " +
               "\(formatter.string(from: NSNumber(value: sw.longitude))!) | " +
               "NE: \(formatter.string(from: NSNumber(value: ne.latitude))!), " +
               "\(formatter.string(from: NSNumber(value: ne.longitude))!)"
    }

    private func updateTileEstimate() {
        guard let bounds = mapBounds else { return }
        estimatedTiles = offlineService.estimateTileCount(
            bounds: bounds,
            minZoom: minZoom,
            maxZoom: maxZoom
        )
    }

    private func startDownload() {
        guard let bounds = mapBounds else { return }

        // Save to database
        let repo = MapRegionRepository(dbPool: database.dbPool)
        var region = MapRegion(
            name: name,
            description: description.isEmpty ? nil : description,
            northLatitude: bounds.ne.latitude,
            southLatitude: bounds.sw.latitude,
            eastLongitude: bounds.ne.longitude,
            westLongitude: bounds.sw.longitude,
            minZoom: minZoom,
            maxZoom: maxZoom,
            tileCount: estimatedTiles,
            status: .downloading
        )

        do {
            region = try repo.create(region)

            // Start MapLibre download
            _ = try offlineService.downloadRegion(
                name: name,
                bounds: bounds,
                minZoom: Double(minZoom),
                maxZoom: Double(maxZoom)
            )

            onDownloadStarted?()
            dismiss()
        } catch {
            // Download start failed - error: \(error.localizedDescription)
        }
    }
}

// MARK: - Region Selection Map View

struct RegionSelectionMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedBounds: MLNCoordinateBounds?

    @State private var centerCoordinate = CLLocationCoordinate2D(
        latitude: 39.8283,
        longitude: -98.5795
    )
    @State private var zoomLevel: Double = 8

    var body: some View {
        NavigationStack {
            ZStack {
                RegionSelectionMapViewRepresentable(
                    centerCoordinate: $centerCoordinate,
                    zoomLevel: $zoomLevel
                )
                .ignoresSafeArea()

                // Selection rectangle overlay
                GeometryReader { geometry in
                    let rectSize = min(geometry.size.width, geometry.size.height) * 0.7
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 3)
                        .background(Color.blue.opacity(0.1))
                        .frame(width: rectSize, height: rectSize)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                }
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Text("Pan and zoom to select area")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Select Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        confirmSelection()
                    }
                }
            }
        }
    }

    private func confirmSelection() {
        // Calculate bounds based on visible region
        // This is a simplified calculation - the actual bounds depend on map view size
        let latSpan = 0.5 / pow(2, zoomLevel - 8)
        let lonSpan = 0.5 / pow(2, zoomLevel - 8)

        let sw = CLLocationCoordinate2D(
            latitude: centerCoordinate.latitude - latSpan,
            longitude: centerCoordinate.longitude - lonSpan
        )
        let ne = CLLocationCoordinate2D(
            latitude: centerCoordinate.latitude + latSpan,
            longitude: centerCoordinate.longitude + lonSpan
        )

        selectedBounds = MLNCoordinateBounds(sw: sw, ne: ne)
        dismiss()
    }
}

// MARK: - Region Selection Map Representable

struct RegionSelectionMapViewRepresentable: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var zoomLevel: Double

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setCenter(centerCoordinate, zoomLevel: zoomLevel, animated: false)
        mapView.styleURL = URL(string: "https://demotiles.maplibre.org/style.json")
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Updates handled by delegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: RegionSelectionMapViewRepresentable

        init(_ parent: RegionSelectionMapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            parent.centerCoordinate = mapView.centerCoordinate
            parent.zoomLevel = mapView.zoomLevel
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Add OpenTopoMap layer
            let options: [MLNTileSourceOption: Any] = [
                .tileSize: NSNumber(value: 256),
                .minimumZoomLevel: NSNumber(value: 1),
                .maximumZoomLevel: NSNumber(value: 17)
            ]

            let source = MLNRasterTileSource(
                identifier: "opentopomap",
                tileURLTemplates: ["https://tile.opentopomap.org/{z}/{x}/{y}.png"],
                options: options
            )
            style.addSource(source)

            let layer = MLNRasterStyleLayer(identifier: "opentopomap-layer", source: source)
            style.addLayer(layer)
        }
    }
}

#Preview {
    OfflineRegionManagerView()
}
