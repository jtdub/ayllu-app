import Foundation
import GRDB
import CoreLocation

/// Repository for Photo CRUD operations
struct PhotoRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    /// Creates a new photo and returns it with the assigned ID
    @discardableResult
    func create(_ photo: Photo) throws -> Photo {
        try dbPool.write { db in
            var newPhoto = photo
            try newPhoto.insert(db)
            return newPhoto
        }
    }

    // MARK: - Read

    /// Fetches all photos, optionally filtered
    func fetchAll(
        projectId: Int64? = nil,
        waypointId: Int64? = nil
    ) throws -> [Photo] {
        try dbPool.read { db in
            var query = Photo.all().order(Photo.Columns.timestamp.desc)

            if let projectId = projectId {
                query = query.filter(Photo.Columns.projectId == projectId)
            }

            if let waypointId = waypointId {
                query = query.filter(Photo.Columns.waypointId == waypointId)
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches a photo by ID
    func fetchById(_ id: Int64) throws -> Photo? {
        try dbPool.read { db in
            try Photo.fetchOne(db, key: id)
        }
    }

    /// Fetches photos within a bounding box
    func fetchInBoundingBox(
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        projectId: Int64? = nil
    ) throws -> [Photo] {
        try dbPool.read { db in
            var query = Photo
                .filter(Photo.Columns.latitude != nil)
                .filter(Photo.Columns.longitude != nil)
                .filter(Photo.Columns.latitude >= south)
                .filter(Photo.Columns.latitude <= north)
                .filter(Photo.Columns.longitude >= west)
                .filter(Photo.Columns.longitude <= east)

            if let projectId = projectId {
                query = query.filter(Photo.Columns.projectId == projectId)
            }

            return try query.fetchAll(db)
        }
    }

    // MARK: - Update

    /// Updates an existing photo
    @discardableResult
    func update(_ photo: Photo) throws -> Photo {
        try dbPool.write { db in
            var updatedPhoto = photo
            updatedPhoto.updatedAt = Date()
            try updatedPhoto.update(db)
            return updatedPhoto
        }
    }

    /// Links a photo to a waypoint
    func linkToWaypoint(photoId: Int64, waypointId: Int64?) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE photos SET waypointId = ?, updatedAt = ? WHERE id = ?",
                arguments: [waypointId, Date(), photoId]
            )
        }
    }

    /// Updates the caption for a photo
    func updateCaption(photoId: Int64, caption: String?) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE photos SET caption = ?, updatedAt = ? WHERE id = ?",
                arguments: [caption, Date(), photoId]
            )
        }
    }

    // MARK: - Delete

    /// Deletes a photo by ID (does not delete the file)
    func delete(id: Int64) throws {
        try dbPool.write { db in
            _ = try Photo.deleteOne(db, key: id)
        }
    }

    /// Deletes a photo
    func delete(_ photo: Photo) throws {
        guard let id = photo.id else { return }
        try delete(id: id)
    }

    /// Deletes all photos for a project
    func deleteAll(projectId: Int64) throws {
        try dbPool.write { db in
            _ = try Photo
                .filter(Photo.Columns.projectId == projectId)
                .deleteAll(db)
        }
    }

    // MARK: - Count

    /// Returns the number of photos for a project
    func countForProject(_ projectId: Int64) throws -> Int {
        try dbPool.read { db in
            try Photo
                .filter(Photo.Columns.projectId == projectId)
                .fetchCount(db)
        }
    }

    /// Returns the total number of photos
    func count() throws -> Int {
        try dbPool.read { db in
            try Photo.fetchCount(db)
        }
    }
}
