import Foundation

/// Parses GeoJSON files into importable items
struct GeoJSONImportService {
    enum GeoJSONImportError: LocalizedError {
        case invalidJSON
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "The file does not contain valid JSON."
            case .unsupportedFormat: return "The GeoJSON format is not supported."
            }
        }
    }

    /// Parses GeoJSON data into an array of ParsedItems
    static func parse(data: Data) throws -> [ParsedItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeoJSONImportError.invalidJSON
        }

        let jsonType = json["type"] as? String

        if jsonType == "FeatureCollection" {
            guard let features = json["features"] as? [[String: Any]] else {
                return []
            }
            return features.flatMap { parseFeature($0) }
        } else if jsonType == "Feature" {
            return parseFeature(json)
        } else {
            throw GeoJSONImportError.unsupportedFormat
        }
    }

    private static func parseFeature(_ feature: [String: Any]) -> [ParsedItem] {
        guard let geometry = feature["geometry"] as? [String: Any],
              let geometryType = geometry["type"] as? String else {
            return []
        }

        let properties = feature["properties"] as? [String: Any] ?? [:]
        let name = (properties["name"] as? String)
            ?? (properties["Name"] as? String)
            ?? (properties["title"] as? String)
        let description = (properties["description"] as? String)
            ?? (properties["Description"] as? String)

        switch geometryType {
        case "Point":
            return [parsePoint(geometry, name: name, description: description)].compactMap { $0 }
        case "Polygon":
            return [parsePolygon(geometry, name: name, description: description)].compactMap { $0 }
        case "LineString":
            return [parseLineString(geometry, name: name, description: description)].compactMap { $0 }
        case "MultiPoint":
            return parseMultiPoint(geometry, name: name, description: description)
        default:
            return []
        }
    }

    private static func parsePoint(
        _ geometry: [String: Any],
        name: String?,
        description: String?
    ) -> ParsedItem? {
        guard let coords = geometry["coordinates"] as? [Double],
              coords.count >= 2 else {
            return nil
        }

        let waypoint = ParsedWaypoint(
            name: name ?? "Imported Point",
            description: description,
            latitude: coords[1],
            longitude: coords[0],
            altitude: coords.count >= 3 ? coords[2] : nil
        )
        return .waypoint(waypoint)
    }

    private static func parsePolygon(
        _ geometry: [String: Any],
        name: String?,
        description: String?
    ) -> ParsedItem? {
        guard let rings = geometry["coordinates"] as? [[[Double]]],
              let exteriorRing = rings.first,
              exteriorRing.count >= 4 else {
            return nil
        }

        // Strip the closing duplicate vertex
        var coords = exteriorRing
        if let first = coords.first, let last = coords.last,
           first[0] == last[0] && first[1] == last[1] {
            coords.removeLast()
        }

        let geo = ParsedGeometry(
            name: name ?? "Imported Polygon",
            description: description,
            geometryType: .polygon,
            coordinates: coords
        )
        return .geometry(geo)
    }

    private static func parseLineString(
        _ geometry: [String: Any],
        name: String?,
        description: String?
    ) -> ParsedItem? {
        guard let coords = geometry["coordinates"] as? [[Double]],
              coords.count >= 2 else {
            return nil
        }

        let geo = ParsedGeometry(
            name: name ?? "Imported Line",
            description: description,
            geometryType: .polyline,
            coordinates: coords
        )
        return .geometry(geo)
    }

    private static func parseMultiPoint(
        _ geometry: [String: Any],
        name: String?,
        description: String?
    ) -> [ParsedItem] {
        guard let points = geometry["coordinates"] as? [[Double]] else {
            return []
        }

        return points.enumerated().compactMap { index, coords in
            guard coords.count >= 2 else { return nil }
            let waypoint = ParsedWaypoint(
                name: name ?? "Point \(index + 1)",
                description: description,
                latitude: coords[1],
                longitude: coords[0],
                altitude: coords.count >= 3 ? coords[2] : nil
            )
            return .waypoint(waypoint)
        }
    }
}
