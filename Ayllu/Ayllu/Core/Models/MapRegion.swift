import Foundation
import GRDB
import CoreLocation

/// An offline map region with downloaded tiles
struct MapRegion: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var name: String
    var description: String?
    var northLatitude: Double
    var southLatitude: Double
    var eastLongitude: Double
    var westLongitude: Double
    var minZoom: Int
    var maxZoom: Int
    var tileCount: Int64?
    var downloadedBytes: Int64?
    var totalBytes: Int64?
    var status: DownloadStatus
    var downloadError: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        name: String,
        description: String? = nil,
        northLatitude: Double,
        southLatitude: Double,
        eastLongitude: Double,
        westLongitude: Double,
        minZoom: Int = 1,
        maxZoom: Int = 16,
        tileCount: Int64? = nil,
        downloadedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        status: DownloadStatus = .pending,
        downloadError: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.northLatitude = northLatitude
        self.southLatitude = southLatitude
        self.eastLongitude = eastLongitude
        self.westLongitude = westLongitude
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.tileCount = tileCount
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.status = status
        self.downloadError = downloadError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Center coordinate of the region
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (northLatitude + southLatitude) / 2,
            longitude: (eastLongitude + westLongitude) / 2
        )
    }

    /// Download progress (0.0 to 1.0)
    var downloadProgress: Double {
        guard let downloaded = downloadedBytes, let total = totalBytes, total > 0 else {
            return 0
        }
        return Double(downloaded) / Double(total)
    }

    /// Formatted storage size
    var formattedSize: String {
        guard let bytes = downloadedBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Check if a coordinate is within this region
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= southLatitude &&
        coordinate.latitude <= northLatitude &&
        coordinate.longitude >= westLongitude &&
        coordinate.longitude <= eastLongitude
    }
}

// MARK: - Download Status

enum DownloadStatus: String, Codable, CaseIterable {
    case pending
    case downloading
    case paused
    case complete
    case failed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .complete: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
}

// MARK: - GRDB Conformance

extension MapRegion: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "map_regions"

    enum Columns: String, ColumnExpression {
        case id, name, description
        case northLatitude, southLatitude
        case eastLongitude, westLongitude
        case minZoom, maxZoom
        case tileCount, downloadedBytes, totalBytes
        case status, downloadError
        case createdAt, updatedAt
    }

    init(row: Row) throws {
        id = row[Columns.id]
        name = row[Columns.name]
        description = row[Columns.description]
        northLatitude = row[Columns.northLatitude]
        southLatitude = row[Columns.southLatitude]
        eastLongitude = row[Columns.eastLongitude]
        westLongitude = row[Columns.westLongitude]
        minZoom = row[Columns.minZoom]
        maxZoom = row[Columns.maxZoom]
        tileCount = row[Columns.tileCount]
        downloadedBytes = row[Columns.downloadedBytes]
        totalBytes = row[Columns.totalBytes]
        downloadError = row[Columns.downloadError]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]

        if let statusString = row[Columns.status] as? String {
            status = DownloadStatus(rawValue: statusString) ?? .pending
        } else {
            status = .pending
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.description] = description
        container[Columns.northLatitude] = northLatitude
        container[Columns.southLatitude] = southLatitude
        container[Columns.eastLongitude] = eastLongitude
        container[Columns.westLongitude] = westLongitude
        container[Columns.minZoom] = minZoom
        container[Columns.maxZoom] = maxZoom
        container[Columns.tileCount] = tileCount
        container[Columns.downloadedBytes] = downloadedBytes
        container[Columns.totalBytes] = totalBytes
        container[Columns.status] = status.rawValue
        container[Columns.downloadError] = downloadError
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }

    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
