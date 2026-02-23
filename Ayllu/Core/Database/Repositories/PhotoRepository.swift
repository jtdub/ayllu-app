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

    // MARK: - Spatial Queries

    /// Fetches photos within a radius of a point
    func fetchNearby(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        projectId: Int64? = nil,
        limit: Int = 50
    ) throws -> [Photo] {
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
            .compactMap { photo -> (Photo, Double)? in
                guard let coord = photo.coordinate else { return nil }
                let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let distance = location.distance(from: center)
                return distance <= radiusMeters ? (photo, distance) : nil
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
            .prefix(limit))
    }

    // MARK: - Search

    /// Searches photos by caption
    func search(term: String, projectId: Int64? = nil) throws -> [Photo] {
        try dbPool.read { db in
            let pattern = "%\(term)%"
            var query = Photo
                .filter(Photo.Columns.caption.like(pattern))
                .order(Photo.Columns.timestamp.desc)

            if let projectId = projectId {
                query = query.filter(Photo.Columns.projectId == projectId)
            }

            return try query.fetchAll(db)
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

    /// Deletes a photo and cleans up associated files
    /// Returns the paths of files that were deleted
    @discardableResult
    func deleteWithCleanup(id: Int64) throws -> [String] {
        let photo = try fetchById(id)
        var deletedPaths: [String] = []

        if let photo = photo {
            // Delete main photo file
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: photo.filePath) {
                try? fileManager.removeItem(atPath: photo.filePath)
                deletedPaths.append(photo.filePath)
            }

            // Delete thumbnail if exists
            if let thumbnailPath = photo.thumbnailPath,
               fileManager.fileExists(atPath: thumbnailPath) {
                try? fileManager.removeItem(atPath: thumbnailPath)
                deletedPaths.append(thumbnailPath)
            }
        }

        // Delete database record
        try delete(id: id)

        return deletedPaths
    }

    /// Deletes a photo and cleans up associated files
    @discardableResult
    func deleteWithCleanup(_ photo: Photo) throws -> [String] {
        guard let id = photo.id else { return [] }
        return try deleteWithCleanup(id: id)
    }

    /// Deletes all photos for a project and cleans up files
    /// Returns the paths of files that were deleted
    @discardableResult
    func deleteAllWithCleanup(projectId: Int64) throws -> [String] {
        let photos = try fetchAll(projectId: projectId)
        var deletedPaths: [String] = []
        let fileManager = FileManager.default

        for photo in photos {
            if fileManager.fileExists(atPath: photo.filePath) {
                try? fileManager.removeItem(atPath: photo.filePath)
                deletedPaths.append(photo.filePath)
            }
            if let thumbnailPath = photo.thumbnailPath,
               fileManager.fileExists(atPath: thumbnailPath) {
                try? fileManager.removeItem(atPath: thumbnailPath)
                deletedPaths.append(thumbnailPath)
            }
        }

        // Delete database records
        try deleteAll(projectId: projectId)

        return deletedPaths
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

    /// Returns the number of photos for a waypoint
    func countForWaypoint(_ waypointId: Int64) throws -> Int {
        try dbPool.read { db in
            try Photo
                .filter(Photo.Columns.waypointId == waypointId)
                .fetchCount(db)
        }
    }

    /// Returns the number of geotagged photos
    func countGeotagged(projectId: Int64? = nil) throws -> Int {
        try dbPool.read { db in
            var query = Photo
                .filter(Photo.Columns.latitude != nil)
                .filter(Photo.Columns.longitude != nil)

            if let projectId = projectId {
                query = query.filter(Photo.Columns.projectId == projectId)
            }

            return try query.fetchCount(db)
        }
    }

    /// Returns the total number of photos
    func count() throws -> Int {
        try dbPool.read { db in
            try Photo.fetchCount(db)
        }
    }
}
