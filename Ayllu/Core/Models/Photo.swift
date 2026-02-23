import Foundation
import GRDB
import CoreLocation

/// A geotagged photo with EXIF metadata
struct Photo: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var projectId: Int64
    var waypointId: Int64?
    var filePath: String
    var thumbnailPath: String?
    var caption: String?
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var heading: Double?
    var timestamp: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        projectId: Int64,
        waypointId: Int64? = nil,
        filePath: String,
        thumbnailPath: String? = nil,
        caption: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        heading: Double? = nil,
        timestamp: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.waypointId = waypointId
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.caption = caption
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.heading = heading
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Whether this photo has GPS coordinates
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    /// Returns a CLLocationCoordinate2D if coordinates exist
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Full file URL for the photo
    var fileURL: URL? {
        URL(fileURLWithPath: filePath)
    }

    /// Full file URL for the thumbnail
    var thumbnailURL: URL? {
        guard let path = thumbnailPath else { return nil }
        return URL(fileURLWithPath: path)
    }
}

// MARK: - GRDB Conformance

extension Photo: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "photos"

    // Define associations
    static let project = belongsTo(Project.self)
    static let waypoint = belongsTo(Waypoint.self)

    enum Columns: String, ColumnExpression {
        case id, projectId, waypointId
        case filePath, thumbnailPath, caption
        case latitude, longitude, altitude, heading
        case timestamp, createdAt, updatedAt
    }

    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
