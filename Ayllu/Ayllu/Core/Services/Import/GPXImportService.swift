import Foundation
import CoreGPX

/// Parses GPX files into importable items
struct GPXImportService {
    enum GPXImportError: LocalizedError {
        case invalidData
        case parseFailure

        var errorDescription: String? {
            switch self {
            case .invalidData: return "The file does not contain valid GPX data."
            case .parseFailure: return "Failed to parse the GPX file."
            }
        }
    }

    /// Parses GPX data into an array of ParsedItems
    static func parse(data: Data) throws -> [ParsedItem] {
        let parser = GPXParser(withData: data)
        guard let root = parser.parsedData() else {
            throw GPXImportError.parseFailure
        }

        return root.waypoints.enumerated().compactMap { index, gpxWaypoint -> ParsedItem? in
            guard let lat = gpxWaypoint.latitude, let lon = gpxWaypoint.longitude else {
                return nil
            }

            let waypoint = ParsedWaypoint(
                index: index,
                name: gpxWaypoint.name ?? "Imported Waypoint",
                description: gpxWaypoint.desc ?? gpxWaypoint.comment,
                latitude: lat,
                longitude: lon,
                altitude: gpxWaypoint.elevation,
                category: mapCategory(from: gpxWaypoint.type)
            )
            return .waypoint(waypoint)
        }
    }

    private static func mapCategory(from type: String?) -> WaypointCategory? {
        guard let type = type?.lowercased() else { return nil }
        return WaypointCategory.allCases.first {
            $0.rawValue == type || $0.displayName.lowercased() == type
        }
    }
}
