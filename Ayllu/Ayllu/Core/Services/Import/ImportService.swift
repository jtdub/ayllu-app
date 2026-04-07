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

                case .geometry(let parsed):
                    var geometry = Geometry(
                        projectId: projectId,
                        name: parsed.name,
                        description: parsed.description,
                        geometryType: parsed.geometryType,
                        coordinates: parsed.coordinates
                    )
                    try geometry.insert(db)

                    // Save denormalized vertices for spatial queries
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
        }

        return result
    }
}
