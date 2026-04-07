import Foundation
import CoreLocation
import GRDB

/// Coordinates import operations across all formats
struct ImportService {
    /// Persists parsed items to the database in a single transaction
    static func persistItems(
        _ items: [ParsedItem],
        projectId: Int64,
        dbPool: DatabasePool
    ) throws -> ImportResult {
        var result = ImportResult()

        try dbPool.write { db in
            for item in items {
                switch item {
                case .waypoint(let parsed):
                    try insertWaypoint(parsed, projectId: projectId, db: db, result: &result)
                case .geometry(let parsed):
                    try insertGeometry(parsed, projectId: projectId, db: db, result: &result)
                }
            }
        }

        return result
    }

    private static func insertWaypoint(
        _ parsed: ParsedWaypoint,
        projectId: Int64,
        db: Database,
        result: inout ImportResult
    ) throws {
        guard (-90...90).contains(parsed.latitude),
              (-180...180).contains(parsed.longitude) else {
            result.errors.append(
                "\(parsed.name): invalid coordinates (\(parsed.latitude), \(parsed.longitude))"
            )
            return
        }

        var waypoint = Waypoint(
            projectId: projectId,
            name: parsed.name,
            description: parsed.description,
            latitude: parsed.latitude,
            longitude: parsed.longitude,
            altitude: parsed.altitude,
            tags: parsed.tags,
            customFields: parsed.customFields,
            category: parsed.category
        )
        try waypoint.insert(db)
        result.waypointsCreated += 1
    }

    private static func insertGeometry(
        _ parsed: ParsedGeometry,
        projectId: Int64,
        db: Database,
        result: inout ImportResult
    ) throws {
        var geometry = Geometry(
            projectId: projectId,
            name: parsed.name,
            description: parsed.description,
            geometryType: parsed.geometryType,
            coordinates: parsed.coordinates
        )
        try geometry.insert(db)

        if let geometryId = geometry.id {
            let coords = geometry.clLocationCoordinates
            for (index, coord) in coords.enumerated() {
                var vertex = GeometryVertex(
                    geometryId: geometryId,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    sortOrder: index
                )
                try vertex.insert(db)
            }
        }

        result.geometriesCreated += 1
    }
}
