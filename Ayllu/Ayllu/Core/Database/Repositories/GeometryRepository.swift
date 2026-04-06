import Foundation
import GRDB
import CoreLocation

/// Repository for Geometry CRUD operations
struct GeometryRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    @discardableResult
    func create(_ geometry: Geometry) throws -> Geometry {
        try dbPool.write { db in
            var newGeometry = geometry
            try newGeometry.insert(db)

            // Save denormalized vertices
            if let geometryId = newGeometry.id {
                try saveVerticesInTransaction(db, geometryId: geometryId, coordinates: geometry.clLocationCoordinates)
            }

            return newGeometry
        }
    }

    // MARK: - Read

    /// Fetches all non-deleted geometries, optionally filtered by project
    func fetchAll(projectId: Int64? = nil) throws -> [Geometry] {
        try dbPool.read { db in
            var query = Geometry
                .filter(Geometry.Columns.deletedAt == nil)
                .order(Geometry.Columns.createdAt.desc)
            if let projectId {
                query = query.filter(Geometry.Columns.projectId == projectId)
            }
            return try query.fetchAll(db)
        }
    }

    /// Fetches geometries linked to a specific record
    func fetchByRecord(_ recordId: Int64) throws -> [Geometry] {
        try dbPool.read { db in
            try Geometry
                .filter(Geometry.Columns.recordId == recordId)
                .filter(Geometry.Columns.deletedAt == nil)
                .order(Geometry.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetches a geometry by ID
    func fetchById(_ id: Int64) throws -> Geometry? {
        try dbPool.read { db in
            try Geometry.fetchOne(db, key: id)
        }
    }

    /// Fetches vertices for a geometry
    func fetchVertices(geometryId: Int64) throws -> [GeometryVertex] {
        try dbPool.read { db in
            try GeometryVertex
                .filter(GeometryVertex.Columns.geometryId == geometryId)
                .order(GeometryVertex.Columns.sortOrder.asc)
                .fetchAll(db)
        }
    }

    // MARK: - Update

    @discardableResult
    func update(_ geometry: Geometry) throws -> Geometry {
        try dbPool.write { db in
            var updated = geometry
            updated.updatedAt = Date()
            try updated.update(db)

            // Update denormalized vertices
            if let geometryId = updated.id {
                try saveVerticesInTransaction(db, geometryId: geometryId, coordinates: geometry.clLocationCoordinates)
            }

            return updated
        }
    }

    // MARK: - Delete

    /// Soft deletes a geometry
    func delete(id: Int64) throws {
        try dbPool.write { db in
            guard var geometry = try Geometry.fetchOne(db, key: id) else { return }
            geometry.deletedAt = Date()
            try geometry.update(db)
        }
    }

    /// Permanently deletes a geometry (vertices cascade via FK)
    func permanentlyDelete(id: Int64) throws {
        try dbPool.write { db in
            _ = try Geometry.deleteOne(db, key: id)
        }
    }

    // MARK: - Count

    func countByRecord(_ recordId: Int64) throws -> Int {
        try dbPool.read { db in
            try Geometry
                .filter(Geometry.Columns.recordId == recordId)
                .filter(Geometry.Columns.deletedAt == nil)
                .fetchCount(db)
        }
    }

    func countForProject(_ projectId: Int64) throws -> Int {
        try dbPool.read { db in
            try Geometry
                .filter(Geometry.Columns.projectId == projectId)
                .filter(Geometry.Columns.deletedAt == nil)
                .fetchCount(db)
        }
    }

    // MARK: - Private

    private func saveVerticesInTransaction(
        _ db: Database,
        geometryId: Int64,
        coordinates: [CLLocationCoordinate2D]
    ) throws {
        // Delete existing vertices
        try GeometryVertex
            .filter(GeometryVertex.Columns.geometryId == geometryId)
            .deleteAll(db)

        // Insert new vertices
        for (index, coord) in coordinates.enumerated() {
            var vertex = GeometryVertex(
                geometryId: geometryId,
                latitude: coord.latitude,
                longitude: coord.longitude,
                sortOrder: index
            )
            try vertex.insert(db)
        }
    }
}
