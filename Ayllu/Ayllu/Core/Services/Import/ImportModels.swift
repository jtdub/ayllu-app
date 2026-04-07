import Foundation

/// A parsed item ready for preview and import
enum ParsedItem: Identifiable {
    case waypoint(ParsedWaypoint)
    case geometry(ParsedGeometry)

    var id: String {
        switch self {
        case .waypoint(let wp): return "wp-\(wp.index)-\(wp.name)"
        case .geometry(let geo): return "geo-\(geo.index)-\(geo.name)"
        }
    }

    var name: String {
        switch self {
        case .waypoint(let wp): return wp.name
        case .geometry(let geo): return geo.name
        }
    }

    var isWaypoint: Bool {
        if case .waypoint = self { return true }
        return false
    }
}

/// A waypoint parsed from an import file, not yet persisted
struct ParsedWaypoint {
    var index: Int = 0
    var name: String
    var description: String?
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var category: WaypointCategory?
    var tags: [String] = []
    var customFields: [String: String] = [:]
}

/// A geometry parsed from an import file, not yet persisted
struct ParsedGeometry {
    var index: Int = 0
    var name: String
    var description: String?
    var geometryType: GeometryType
    var coordinates: [[Double]]
}

/// Result of an import operation
struct ImportResult {
    var waypointsCreated: Int = 0
    var geometriesCreated: Int = 0
    var errors: [String] = []

    var totalCreated: Int { waypointsCreated + geometriesCreated }
    var hasErrors: Bool { !errors.isEmpty }
}

/// Mapping of CSV columns to waypoint fields
struct CSVColumnMapping {
    var nameColumn: String
    var latitudeColumn: String
    var longitudeColumn: String
    var descriptionColumn: String?
    var altitudeColumn: String?
    var categoryColumn: String?
}

/// Supported import file formats
enum ImportFormat {
    case gpx
    case csv
    case geojson

    static func detect(from url: URL) -> Self? {
        switch url.pathExtension.lowercased() {
        case "gpx": return .gpx
        case "csv": return .csv
        case "geojson", "json": return .geojson
        default: return nil
        }
    }
}
