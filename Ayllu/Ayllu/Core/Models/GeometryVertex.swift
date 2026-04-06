import Foundation
import GRDB
import CoreLocation

/// A single vertex of a geometry, stored denormalized for spatial queries
struct GeometryVertex: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var geometryId: Int64
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var sortOrder: Int

    init(
        id: Int64? = nil,
        geometryId: Int64,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.geometryId = geometryId
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.sortOrder = sortOrder
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - GRDB Conformance

extension GeometryVertex: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "geometry_vertices"

    // Associations
    static let geometry = belongsTo(Geometry.self)

    enum Columns: String, ColumnExpression {
        case id, geometryId
        case latitude, longitude, altitude
        case sortOrder
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
