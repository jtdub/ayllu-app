// Temporarily disabling linting rules for debugging offline map download issues
// swiftlint:disable file_length type_body_length function_body_length no_print_statements
import Foundation
import MapLibre
import CoreLocation
import Combine
import Network

/// Service for managing offline map tile downloads using MapLibre
@Observable
final class OfflineMapService {
    // MARK: - Properties

    private(set) var downloadingRegions: [String: DownloadProgress] = [:]
    private(set) var isInitialized = false

    private let offlineStorage: MLNOfflineStorage
    private var progressObservers: [NSObjectProtocol] = []
    private let styleServer = StyleServerService()
    private var styleURL: URL?

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

        // Start local HTTP server to serve style JSON
        // Required because MapLibre's offline pack system needs HTTP URLs
        do {
            let urlString = try styleServer.start()
            styleURL = URL(string: urlString)
            print("✅ [OfflineMap] Style server started: \(urlString)")
        } catch {
            print("❌ [OfflineMap] Failed to start style server: \(error)")
            styleURL = nil
        }

        isInitialized = true
    }

    deinit {
        progressObservers.forEach { NotificationCenter.default.removeObserver($0) }
        styleServer.stop()
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
        print("🗺️ [OfflineMap] Starting download for region: \(name)")
        print("🗺️ [OfflineMap] Bounds: SW(\(bounds.sw.latitude), \(bounds.sw.longitude)) " +
              "NE(\(bounds.ne.latitude), \(bounds.ne.longitude))")
        print("🗺️ [OfflineMap] Zoom levels: \(minZoom) to \(maxZoom)")

        guard isInitialized else {
            print("❌ [OfflineMap] ERROR: Service not initialized")
            throw OfflineMapError.notInitialized
        }

        // Validate bounds
        guard bounds.sw.latitude < bounds.ne.latitude,
              bounds.sw.longitude < bounds.ne.longitude else {
            print("❌ [OfflineMap] ERROR: Invalid bounds")
            throw OfflineMapError.invalidBounds
        }

        // Use HTTP style URL from local server
        // MapLibre requires HTTP URLs to properly discover and download tiles
        guard let styleURL = styleURL else {
            print("❌ [OfflineMap] ERROR: Style server not available")
            throw OfflineMapError.storageError("Style server not available")
        }

        print("🗺️ [OfflineMap] Using style URL: \(styleURL.absoluteString)")

        // Create region definition
        let region = MLNTilePyramidOfflineRegion(
            styleURL: styleURL,
            bounds: bounds,
            fromZoomLevel: minZoom,
            toZoomLevel: maxZoom
        )

        // Create context with region name
        let context = name.data(using: .utf8)!

        // Pre-compute region ID (same as packIdentifier would compute)
        // This allows us to initialize progress tracking BEFORE addPack callback
        let regionId = String(context.hashValue)
        print("🗺️ [OfflineMap] Pre-computed region ID: \(regionId)")

        // Initialize progress tracking on main thread for @Observable to work
        // This prevents race condition where progress notifications arrive before dictionary is updated
        Task { @MainActor in
            downloadingRegions[regionId] = DownloadProgress(
                regionId: regionId,
                name: name,
                completedResources: 0,
                totalResources: 0,
                completedBytes: 0,
                status: .downloading
            )
            print("🗺️ [OfflineMap] Progress tracking pre-initialized for \(regionId)")
        }

        print("🗺️ [OfflineMap] Calling addPack...")

        // Start download
        offlineStorage.addPack(for: region, withContext: context) { [weak self] pack, error in
            if let error = error {
                print("❌ [OfflineMap] addPack ERROR: \(error.localizedDescription)")
                print("❌ [OfflineMap] Error details: \(error)")
                // Remove from dictionary on error
                DispatchQueue.main.async {
                    self?.downloadingRegions.removeValue(forKey: regionId)
                }
                return
            }

            guard let pack = pack else {
                print("❌ [OfflineMap] ERROR: Pack is nil but no error provided")
                DispatchQueue.main.async {
                    self?.downloadingRegions.removeValue(forKey: regionId)
                }
                return
            }

            print("✅ [OfflineMap] Pack created successfully")
            print("🗺️ [OfflineMap] Verified region ID: \(self?.packIdentifier(pack) ?? "unknown")")

            // Start the download
            print("🗺️ [OfflineMap] Starting pack.resume()...")
            pack.resume()
            print("✅ [OfflineMap] Pack resumed, download should be in progress")
            print("🗺️ [OfflineMap] Pack region definition: \(pack.region)")

            // Debug: Check if tiles are being requested
            if let tilePyramid = pack.region as? MLNTilePyramidOfflineRegion {
                print("🗺️ [OfflineMap] Style URL: \(tilePyramid.styleURL)")
                print("🗺️ [OfflineMap] Bounds: \(tilePyramid.bounds)")
                print("🗺️ [OfflineMap] Zoom range: \(tilePyramid.minimumZoomLevel) to \(tilePyramid.maximumZoomLevel)")
            }
        }

        print("🗺️ [OfflineMap] Returning region ID: \(regionId)")
        return regionId
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
        guard let pack = notification.object as? MLNOfflinePack else {
            print("⚠️ [OfflineMap] Progress notification but no pack object")
            return
        }

        let progress = pack.progress
        let regionId = packIdentifier(pack)

        print("📊 [OfflineMap] Progress update for \(regionId): " +
              "\(progress.countOfResourcesCompleted)/\(progress.countOfResourcesExpected) resources, " +
              "\(progress.countOfBytesCompleted) bytes")

        // Debug: Show pack state
        print("📊 [OfflineMap] Pack state: \(pack.state.rawValue)")

        // Debug: If only 1 resource, something is wrong
        if progress.countOfResourcesExpected == 1 {
            print("⚠️ [OfflineMap] WARNING: Only 1 resource expected! Tiles may not be downloading.")
            print("⚠️ [OfflineMap] This suggests the style was loaded but tiles weren't discovered.")
        }

        let status: DownloadStatus
        if progress.countOfResourcesCompleted == progress.countOfResourcesExpected {
            status = .complete
            print("✅ [OfflineMap] Download COMPLETE for \(regionId)")

            // Debug: Check if this is a premature completion
            if progress.countOfResourcesExpected == 1 {
                print("⚠️ [OfflineMap] WARNING: Download 'completed' with only 1 resource.")
                print("⚠️ [OfflineMap] This is likely just the style, not the tiles!")
            }
        } else {
            status = .downloading
        }

        if var existing = downloadingRegions[regionId] {
            existing.completedResources = progress.countOfResourcesCompleted
            existing.totalResources = progress.countOfResourcesExpected
            existing.completedBytes = progress.countOfBytesCompleted
            existing.status = status
            downloadingRegions[regionId] = existing
        } else {
            print("⚠️ [OfflineMap] Received progress for unknown region: \(regionId)")
        }
    }

    private func handlePackError(_ notification: Notification) {
        guard let pack = notification.object as? MLNOfflinePack else {
            print("⚠️ [OfflineMap] Pack error notification but no pack object")
            return
        }

        let regionId = packIdentifier(pack)

        if let error = notification.userInfo?[MLNOfflinePackUserInfoKey.error] as? Error {
            print("❌ [OfflineMap] Pack ERROR for region \(regionId): \(error.localizedDescription)")
            print("❌ [OfflineMap] Error details: \(error)")

            if var existing = downloadingRegions[regionId] {
                existing.status = .failed
                downloadingRegions[regionId] = existing
            }
        } else {
            print("⚠️ [OfflineMap] Pack error notification but no error in userInfo for region \(regionId)")
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

// MARK: - Style Server Service

/// Minimal HTTP server to serve OpenTopoMap style JSON to MapLibre
/// Required because MapLibre's offline pack system needs HTTP URLs, not data URLs
final class StyleServerService {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.ayllu.styleserver")
    private var port: UInt16 = 0

    private static let openTopoMapStyle: [String: Any] = [
        "version": 8,
        "name": "OpenTopoMap",
        "sources": [
            "opentopo": [
                "type": "raster",
                "tiles": ["https://tile.opentopomap.org/{z}/{x}/{y}.png"],
                "tileSize": 256,
                "attribution": "Map data: © OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap (CC-BY-SA)"
            ]
        ],
        "layers": [
            [
                "id": "opentopo",
                "type": "raster",
                "source": "opentopo",
                "minzoom": 0,
                "maxzoom": 22
            ]
        ]
    ]

    func start() throws -> String {
        // If already running, return existing URL
        if let existingListener = listener, case .ready = existingListener.state, port != 0 {
            let url = "http://127.0.0.1:\(port)/style.json"
            print("🌐 [StyleServer] Already running on port \(port)")
            return url
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        // Try to listen on port 8765
        let listener = try NWListener(using: parameters, on: 8_765)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if let port = listener.port {
                    print("🌐 [StyleServer] Started on port \(port)")
                }
            case .failed(let error):
                print("❌ [StyleServer] Failed: \(error)")
            default:
                break
            }
        }

        listener.start(queue: queue)

        // Wait a bit for listener to be ready
        Thread.sleep(forTimeInterval: 0.1)

        guard case .ready = listener.state, let port = listener.port else {
            throw NSError(domain: "StyleServerService",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to start server"])
        }

        self.port = port.rawValue
        return "http://127.0.0.1:\(port)/style.json"
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            // Parse HTTP request (very minimal - just check for GET /style.json)
            if let request = String(data: data, encoding: .utf8), request.contains("GET /style.json") {
                self.sendStyleResponse(connection)
            } else {
                self.send404(connection)
            }
        }
    }

    private func sendStyleResponse(_ connection: NWConnection) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: Self.openTopoMapStyle, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            send404(connection)
            return
        }

        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(jsonData.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(jsonString)
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func send404(_ connection: NWConnection) {
        let response = """
        HTTP/1.1 404 Not Found\r
        Content-Length: 0\r
        Connection: close\r
        \r

        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
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
// swiftlint:enable file_length type_body_length function_body_length no_print_statements
