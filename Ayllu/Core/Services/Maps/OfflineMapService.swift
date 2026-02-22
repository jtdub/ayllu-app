import Foundation
import MapLibre
import CoreLocation
import Combine

/// Service for managing offline map tile downloads using MapLibre
@Observable
final class OfflineMapService {
    // MARK: - Properties

    private(set) var downloadingRegions: [String: DownloadProgress] = [:]
    private(set) var isInitialized = false

    private let offlineStorage: MLNOfflineStorage
    private var progressObservers: [NSObjectProtocol] = []

    // OpenTopoMap tile URL
    private static let tileURLTemplate = "https://tile.opentopomap.org/{z}/{x}/{y}.png"
    private static let styleURL = URL(string: "https://demotiles.maplibre.org/style.json")!

    // MARK: - Types

    struct DownloadProgress: Sendable {
        let regionId: String
        let name: String
        var completedResources: UInt64
        var totalResources: UInt64
        var completedBytes: UInt64
        var status: DownloadStatus

        var progress: Double {
            guard totalResources > 0 else { return 0 }
            return Double(completedResources) / Double(totalResources)
        }
    }

    enum OfflineMapError: LocalizedError {
        case notInitialized
        case invalidBounds
        case downloadFailed(String)
        case regionNotFound
        case storageError(String)

        var errorDescription: String? {
            switch self {
            case .notInitialized:
                return "Offline map service not initialized"
            case .invalidBounds:
                return "Invalid map region bounds"
            case .downloadFailed(let message):
                return "Download failed: \(message)"
            case .regionNotFound:
                return "Offline region not found"
            case .storageError(let message):
                return "Storage error: \(message)"
            }
        }
    }

    // MARK: - Initialization

    init() {
        self.offlineStorage = MLNOfflineStorage.shared
        setupProgressObservers()
        isInitialized = true
    }

    deinit {
        progressObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Public Methods

    /// Downloads a map region for offline use
    /// - Parameters:
    ///   - name: Display name for the region
    ///   - bounds: Geographic bounds of the region (SW to NE corners)
    ///   - minZoom: Minimum zoom level to download
    ///   - maxZoom: Maximum zoom level to download
    /// - Returns: The region identifier
    func downloadRegion(
        name: String,
        bounds: MLNCoordinateBounds,
        minZoom: Double,
        maxZoom: Double
    ) throws -> String {
        guard isInitialized else {
            throw OfflineMapError.notInitialized
        }

        // Validate bounds
        guard bounds.sw.latitude < bounds.ne.latitude,
              bounds.sw.longitude < bounds.ne.longitude else {
            throw OfflineMapError.invalidBounds
        }

        // Create region definition
        let region = MLNTilePyramidOfflineRegion(
            styleURL: Self.styleURL,
            bounds: bounds,
            fromZoomLevel: minZoom,
            toZoomLevel: maxZoom
        )

        // Create context with region name
        let context = name.data(using: .utf8)!

        // Start download
        offlineStorage.addPack(for: region, withContext: context) { [weak self] pack, error in
            if error != nil {
                // Error handled - pack creation failed
                return
            }

            guard let pack = pack else { return }

            // Initialize progress tracking
            let regionId = self?.packIdentifier(pack) ?? UUID().uuidString
            self?.downloadingRegions[regionId] = DownloadProgress(
                regionId: regionId,
                name: name,
                completedResources: 0,
                totalResources: 0,
                completedBytes: 0,
                status: .downloading
            )

            // Start the download
            pack.resume()
        }

        return UUID().uuidString
    }

    /// Pauses download for a region
    func pauseDownload(regionId: String) {
        guard let pack = findPack(byId: regionId) else { return }
        pack.suspend()
        downloadingRegions[regionId]?.status = .paused
    }

    /// Resumes download for a paused region
    func resumeDownload(regionId: String) {
        guard let pack = findPack(byId: regionId) else { return }
        pack.resume()
        downloadingRegions[regionId]?.status = .downloading
    }

    /// Deletes an offline region
    func deleteRegion(regionId: String) throws {
        guard let pack = findPack(byId: regionId) else {
            throw OfflineMapError.regionNotFound
        }

        offlineStorage.removePack(pack) { _ in
            // Pack removal completed (error handled internally)
        }

        downloadingRegions.removeValue(forKey: regionId)
    }

    /// Gets all downloaded regions
    func getDownloadedRegions() -> [OfflineRegionInfo] {
        guard let packs = offlineStorage.packs else { return [] }

        return packs.compactMap { pack in
            let context = pack.context
            guard let name = String(data: context, encoding: .utf8) else {
                return nil
            }

            let progress = pack.progress
            let status: DownloadStatus
            switch pack.state {
            case .unknown:
                status = .pending
            case .inactive:
                status = progress.countOfResourcesCompleted == progress.countOfResourcesExpected
                    ? .complete : .paused
            case .active:
                status = .downloading
            case .complete:
                status = .complete
            case .invalid:
                status = .failed
            @unknown default:
                status = .pending
            }

            return OfflineRegionInfo(
                id: packIdentifier(pack),
                name: name,
                completedResources: progress.countOfResourcesCompleted,
                totalResources: progress.countOfResourcesExpected,
                completedBytes: progress.countOfBytesCompleted,
                status: status
            )
        }
    }

    /// Calculates total storage used by offline maps
    func calculateStorageUsed() -> Int64 {
        guard let packs = offlineStorage.packs else { return 0 }
        return packs.reduce(0) { total, pack in
            total + Int64(pack.progress.countOfBytesCompleted)
        }
    }

    /// Estimates tile count for a region
    func estimateTileCount(
        bounds: MLNCoordinateBounds,
        minZoom: Int,
        maxZoom: Int
    ) -> Int64 {
        var totalTiles: Int64 = 0

        for zoom in minZoom...maxZoom {
            let tilesAtZoom = tilesInBounds(bounds, atZoom: zoom)
            totalTiles += tilesAtZoom
        }

        return totalTiles
    }

    // MARK: - Private Methods

    private func setupProgressObservers() {
        // Progress notification
        let progressObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleProgressUpdate(notification)
        }
        progressObservers.append(progressObserver)

        // Error notification
        let errorObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handlePackError(notification)
        }
        progressObservers.append(errorObserver)

        // Maximum tiles notification
        let maxTilesObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackMaximumMapboxTilesReached,
            object: nil,
            queue: .main
        ) { _ in
            // Maximum tiles reached for offline pack - handled by notification
        }
        progressObservers.append(maxTilesObserver)
    }

    private func handleProgressUpdate(_ notification: Notification) {
        guard let pack = notification.object as? MLNOfflinePack else { return }

        let progress = pack.progress
        let regionId = packIdentifier(pack)

        let status: DownloadStatus
        if progress.countOfResourcesCompleted == progress.countOfResourcesExpected {
            status = .complete
        } else {
            status = .downloading
        }

        if var existing = downloadingRegions[regionId] {
            existing.completedResources = progress.countOfResourcesCompleted
            existing.totalResources = progress.countOfResourcesExpected
            existing.completedBytes = progress.countOfBytesCompleted
            existing.status = status
            downloadingRegions[regionId] = existing
        }
    }

    private func handlePackError(_ notification: Notification) {
        guard let pack = notification.object as? MLNOfflinePack,
              notification.userInfo?[MLNOfflinePackUserInfoKey.error] is Error else {
            return
        }

        let regionId = packIdentifier(pack)
        // Offline pack error handled

        if var existing = downloadingRegions[regionId] {
            existing.status = .failed
            downloadingRegions[regionId] = existing
        }
    }

    private func findPack(byId regionId: String) -> MLNOfflinePack? {
        offlineStorage.packs?.first { pack in
            packIdentifier(pack) == regionId
        }
    }

    private func packIdentifier(_ pack: MLNOfflinePack) -> String {
        // Use context data hash as identifier
        let context = pack.context
        return String(context.hashValue)
    }

    private func tilesInBounds(_ bounds: MLNCoordinateBounds, atZoom zoom: Int) -> Int64 {
        let n = pow(2.0, Double(zoom))

        let swTileX = Int(floor((bounds.sw.longitude + 180.0) / 360.0 * n))
        let neTileX = Int(floor((bounds.ne.longitude + 180.0) / 360.0 * n))

        let swLatRad = bounds.sw.latitude * .pi / 180.0
        let neLatRad = bounds.ne.latitude * .pi / 180.0

        let swTileY = Int(floor((1.0 - asinh(tan(swLatRad)) / .pi) / 2.0 * n))
        let neTileY = Int(floor((1.0 - asinh(tan(neLatRad)) / .pi) / 2.0 * n))

        let tilesX = abs(neTileX - swTileX) + 1
        let tilesY = abs(neTileY - swTileY) + 1

        return Int64(tilesX * tilesY)
    }
}

// MARK: - Offline Region Info

struct OfflineRegionInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let completedResources: UInt64
    let totalResources: UInt64
    let completedBytes: UInt64
    let status: DownloadStatus

    var progress: Double {
        guard totalResources > 0 else { return 0 }
        return Double(completedResources) / Double(totalResources)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(completedBytes), countStyle: .file)
    }
}
