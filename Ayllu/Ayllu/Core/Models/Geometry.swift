import Foundation
import GRDB
import CoreLocation

/// The type of geometry shape
enum GeometryType: String, Codable, CaseIterable {
    case polygon
    case polyline

    var displayName: String {
        switch self {
        case .polygon: return "Polygon"
        case .polyline: return "Polyline"
        }
    }

    var iconName: String {
        switch self {
        case .polygon: return "pentagon"
        case .polyline: return "line.diagonal"
        }
    }
}

/// A geographic geometry (polygon or polyline) stored as GeoJSON coordinates
struct Geometry: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var projectId: Int64
    var recordId: Int64?
    var name: String
    var description: String?
    var geometryType: GeometryType
    /// Coordinates stored as GeoJSON: [[longitude, latitude], ...]
    var coordinates: [[Double]]
    var area: Double?
    var perimeter: Double?
    var fillColor: String?
    var strokeColor: String?
    var strokeWidth: Double?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var isDeleted: Bool {
        deletedAt != nil
    }

    init(
        id: Int64? = nil,
        projectId: Int64,
        recordId: Int64? = nil,
        name: String,
        description: String? = nil,
        geometryType: GeometryType = .polygon,
        coordinates: [[Double]] = [],
        area: Double? = nil,
        perimeter: Double? = nil,
        fillColor: String? = nil,
        strokeColor: String? = nil,
        strokeWidth: Double? = 2.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.recordId = recordId
        self.name = name
        self.description = description
        self.geometryType = geometryType
        self.coordinates = coordinates
        self.area = area
        self.perimeter = perimeter
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Converts GeoJSON [lon, lat] pairs to CLLocationCoordinate2D array
    var clLocationCoordinates: [CLLocationCoordinate2D] {
        coordinates.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }

    /// Converts CLLocationCoordinate2D array to GeoJSON [lon, lat] pairs
    static func geoJSONCoordinates(from coords: [CLLocationCoordinate2D]) -> [[Double]] {
        coords.map { [$0.longitude, $0.latitude] }
    }

    /// Generates a GeoJSON Feature string for export
    func toGeoJSON() -> String {
        let validCoords = coordinates.filter { $0.count >= 2 }
        let coordsValue: Any
        if geometryType == .polygon {
            let ring = validCoords + (validCoords.first.map { [$0] } ?? [])
            coordsValue = [ring]
        } else {
            coordsValue = validCoords
        }

        let geoJSONType = geometryType == .polygon ? "Polygon" : "LineString"
        let feature: [String: Any] = [
            "type": "Feature",
            "geometry": [
                "type": geoJSONType,
                "coordinates": coordsValue
            ],
            "properties": [
                "name": name
            ]
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: feature,
            options: [.sortedKeys]
        ) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - GRDB Conformance

extension Geometry: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "geometries"

    // Associations
    static let project = belongsTo(Project.self)
    static let record = belongsTo(Record.self)
    static let vertices = hasMany(GeometryVertex.self)

    enum Columns: String, ColumnExpression {
        case id, projectId, recordId
        case name, description, geometryType
        case coordinates, area, perimeter
        case fillColor, strokeColor, strokeWidth
        case createdAt, updatedAt, deletedAt
    }

    init(row: Row) throws {
        id = row[Columns.id]
        projectId = row[Columns.projectId]
        recordId = row[Columns.recordId]
        name = row[Columns.name]
        description = row[Columns.description]
        area = row[Columns.area]
        perimeter = row[Columns.perimeter]
        fillColor = row[Columns.fillColor]
        strokeColor = row[Columns.strokeColor]
        strokeWidth = row[Columns.strokeWidth]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]

        // Decode geometryType
        if let typeString = row[Columns.geometryType] as? String {
            geometryType = GeometryType(rawValue: typeString) ?? .polygon
        } else {
            geometryType = .polygon
        }

        // Decode JSON coordinates
        if let data = row[Columns.coordinates] as? Data {
            coordinates = (try? JSONDecoder().decode([[Double]].self, from: data)) ?? []
        } else if let string = row[Columns.coordinates] as? String,
                  let data = string.data(using: .utf8) {
            coordinates = (try? JSONDecoder().decode([[Double]].self, from: data)) ?? []
        } else {
            coordinates = []
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.projectId] = projectId
        container[Columns.recordId] = recordId
        container[Columns.name] = name
        container[Columns.description] = description
        container[Columns.geometryType] = geometryType.rawValue
        container[Columns.area] = area
        container[Columns.perimeter] = perimeter
        container[Columns.fillColor] = fillColor
        container[Columns.strokeColor] = strokeColor
        container[Columns.strokeWidth] = strokeWidth
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt

        if let data = try? JSONEncoder().encode(coordinates) {
            container[Columns.coordinates] = String(data: data, encoding: .utf8)
        }
    }

    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
