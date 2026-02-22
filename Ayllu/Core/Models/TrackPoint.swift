import Foundation
import GRDB
import CoreLocation

/// An individual GPS fix within a track
struct TrackPoint: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var trackId: Int64
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double?
    var verticalAccuracy: Double?
    var speed: Double?
    var heading: Double?
    var timestamp: Date
    var segmentIndex: Int  // For handling track segments (e.g., after pause)

    init(
        id: Int64? = nil,
        trackId: Int64,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double? = nil,
        verticalAccuracy: Double? = nil,
        speed: Double? = nil,
        heading: Double? = nil,
        timestamp: Date = Date(),
        segmentIndex: Int = 0
    ) {
        self.id = id
        self.trackId = trackId
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.heading = heading
        self.timestamp = timestamp
        self.segmentIndex = segmentIndex
    }

    /// Returns a CLLocationCoordinate2D for map display
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Returns a CLLocation for distance calculations
    var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy ?? -1,
            verticalAccuracy: verticalAccuracy ?? -1,
            timestamp: timestamp
        )
    }

    /// Create from CLLocation
    static func from(location: CLLocation, trackId: Int64, segmentIndex: Int = 0) -> Self {
        Self(
            trackId: trackId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed >= 0 ? location.speed : nil,
            heading: location.course >= 0 ? location.course : nil,
            timestamp: location.timestamp,
            segmentIndex: segmentIndex
        )
    }
}

// MARK: - GRDB Conformance

extension TrackPoint: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "track_points"

    // Define associations
    static let track = belongsTo(Track.self)

    enum Columns: String, ColumnExpression {
        case id, trackId
        case latitude, longitude, altitude
        case horizontalAccuracy, verticalAccuracy
        case speed, heading
        case timestamp, segmentIndex
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
