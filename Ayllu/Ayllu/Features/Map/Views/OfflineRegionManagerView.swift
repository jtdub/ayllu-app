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
                    if regions.isEmpty && offlineService.downloadingRegions.isEmpty {
                        ContentUnavailableView(
                            "No Offline Maps",
                            systemImage: "map",
                            description: Text("Download map regions for offline use")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(mergedRegions) { region in
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
            .task {
                // Periodic sync task to update UI from live download progress
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(0.5))
                    await syncDownloadProgress()
                }
            }
        }
    }

    /// Merges database regions with live download progress
    private var mergedRegions: [MapRegion] {
        regions.map { region in
            // Find matching progress by name (name is stored in context hash)
            if let progress = offlineService.downloadingRegions.values.first(where: { $0.name == region.name }) {
                // Merge live progress into region
                var updated = region
                updated.status = progress.status
                updated.downloadedBytes = Int64(progress.completedBytes)
                updated.totalBytes = Int64(progress.totalResources) * 15_000 // Estimate ~15KB per tile
                return updated
            }

            return region
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

    @MainActor
    private func syncDownloadProgress() async {
        let repo = MapRegionRepository(dbPool: database.dbPool)

        // Sync each downloading region from in-memory to database
        for progress in offlineService.downloadingRegions.values {
            // Find matching region by name (name is the context used in MapLibre)
            if var region = regions.first(where: { $0.name == progress.name }) {
                // Update with live progress
                region.status = progress.status
                region.downloadedBytes = Int64(progress.completedBytes)
                region.totalBytes = Int64(progress.totalResources) * 15_000 // ~15KB per tile estimate

                // Save to database
                _ = try? repo.update(region)
            }
        }

        // Reload regions to pick up changes
        regions = (try? repo.fetchAll()) ?? []
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
        withAnimation {
            regions.removeAll { $0.id == id }
        }
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

#Preview {
    OfflineRegionManagerView()
}
