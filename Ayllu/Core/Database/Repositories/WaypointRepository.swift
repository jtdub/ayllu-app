import Foundation
import GRDB
import CoreLocation

/// Repository for Waypoint CRUD operations with spatial query support
struct WaypointRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    /// Creates a new waypoint and returns it with the assigned ID
    @discardableResult
    func create(_ waypoint: Waypoint) throws -> Waypoint {
        try dbPool.write { db in
            var newWaypoint = waypoint
            try newWaypoint.insert(db)
            return newWaypoint
        }
    }

    /// Creates a quick waypoint with auto-generated name
    @discardableResult
    func createQuick(
        projectId: Int64,
        location: CLLocation,
        category: WaypointCategory? = nil
    ) throws -> Waypoint {
        let count = try countForProject(projectId)
        let name = String(format: "WP-%03d", count + 1)

        let waypoint = Waypoint(
            projectId: projectId,
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            heading: location.course >= 0 ? location.course : nil,
            speed: location.speed >= 0 ? location.speed : nil,
            category: category
        )

        return try create(waypoint)
    }

    // MARK: - Read

    /// Fetches all waypoints for a project
    func fetchAll(
        projectId: Int64? = nil,
        category: WaypointCategory? = nil,
        searchTerm: String? = nil
    ) throws -> [Waypoint] {
        try dbPool.read { db in
            var query = Waypoint.all().order(Waypoint.Columns.createdAt.desc)

            if let projectId = projectId {
                query = query.filter(Waypoint.Columns.projectId == projectId)
            }

            if let category = category {
                query = query.filter(Waypoint.Columns.category == category.rawValue)
            }

            if let search = searchTerm, !search.isEmpty {
                let pattern = "%\(search)%"
                query = query.filter(
                    Waypoint.Columns.name.like(pattern) ||
                    Waypoint.Columns.description.like(pattern)
                )
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches a waypoint by ID
    func fetchById(_ id: Int64) throws -> Waypoint? {
        try dbPool.read { db in
            try Waypoint.fetchOne(db, key: id)
        }
    }

    // MARK: - Spatial Queries

    /// Fetches waypoints within a bounding box
    func fetchInBoundingBox(
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        projectId: Int64? = nil
    ) throws -> [Waypoint] {
        try dbPool.read { db in
            var query = Waypoint
                .filter(Waypoint.Columns.latitude >= south)
                .filter(Waypoint.Columns.latitude <= north)
                .filter(Waypoint.Columns.longitude >= west)
                .filter(Waypoint.Columns.longitude <= east)

            if let projectId = projectId {
                query = query.filter(Waypoint.Columns.projectId == projectId)
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches waypoints within a radius of a point
    func fetchNearby(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        projectId: Int64? = nil,
        limit: Int = 50
    ) throws -> [Waypoint] {
        // First, get rough bounding box (1 degree ≈ 111km at equator)
        let latDelta = radiusMeters / 111_000.0
        let lonDelta = radiusMeters / (111_000.0 * cos(latitude * .pi / 180))

        let candidates = try fetchInBoundingBox(
            north: latitude + latDelta,
            south: latitude - latDelta,
            east: longitude + lonDelta,
            west: longitude - lonDelta,
            projectId: projectId
        )

        // Filter by actual distance
        let center = CLLocation(latitude: latitude, longitude: longitude)
        return Array(candidates
            .filter { $0.location.distance(from: center) <= radiusMeters }
            .sorted { $0.location.distance(from: center) < $1.location.distance(from: center) }
            .prefix(limit))
    }

    // MARK: - Update

    /// Updates an existing waypoint
    @discardableResult
    func update(_ waypoint: Waypoint) throws -> Waypoint {
        try dbPool.write { db in
            var updatedWaypoint = waypoint
            updatedWaypoint.updatedAt = Date()
            try updatedWaypoint.update(db)
            return updatedWaypoint
        }
    }

    // MARK: - Delete

    /// Deletes a waypoint by ID
    func delete(id: Int64) throws {
        try dbPool.write { db in
            _ = try Waypoint.deleteOne(db, key: id)
        }
    }

    /// Deletes a waypoint
    func delete(_ waypoint: Waypoint) throws {
        guard let id = waypoint.id else { return }
        try delete(id: id)
    }

    /// Deletes all waypoints for a project
    func deleteAll(projectId: Int64) throws {
        try dbPool.write { db in
            _ = try Waypoint
                .filter(Waypoint.Columns.projectId == projectId)
                .deleteAll(db)
        }
    }

    // MARK: - Count

    /// Returns the number of waypoints for a project
    func countForProject(_ projectId: Int64) throws -> Int {
        try dbPool.read { db in
            try Waypoint
                .filter(Waypoint.Columns.projectId == projectId)
                .fetchCount(db)
        }
    }

    /// Returns the total number of waypoints
    func count() throws -> Int {
        try dbPool.read { db in
            try Waypoint.fetchCount(db)
        }
    }
}
