import Foundation
import GRDB

/// Repository for MapRegion CRUD operations
struct MapRegionRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    /// Creates a new map region and returns it with the assigned ID
    @discardableResult
    func create(_ region: MapRegion) throws -> MapRegion {
        try dbPool.write { db in
            var newRegion = region
            try newRegion.insert(db)
            return newRegion
        }
    }

    // MARK: - Read

    /// Fetches all map regions
    func fetchAll(status: DownloadStatus? = nil) throws -> [MapRegion] {
        try dbPool.read { db in
            var query = MapRegion.all().order(MapRegion.Columns.createdAt.desc)

            if let status = status {
                query = query.filter(MapRegion.Columns.status == status.rawValue)
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches a map region by ID
    func fetchById(_ id: Int64) throws -> MapRegion? {
        try dbPool.read { db in
            try MapRegion.fetchOne(db, key: id)
        }
    }

    /// Fetches regions that contain a coordinate
    func fetchContaining(latitude: Double, longitude: Double) throws -> [MapRegion] {
        try dbPool.read { db in
            try MapRegion
                .filter(MapRegion.Columns.southLatitude <= latitude)
                .filter(MapRegion.Columns.northLatitude >= latitude)
                .filter(MapRegion.Columns.westLongitude <= longitude)
                .filter(MapRegion.Columns.eastLongitude >= longitude)
                .filter(MapRegion.Columns.status == DownloadStatus.complete.rawValue)
                .fetchAll(db)
        }
    }

    /// Fetches completed regions only
    func fetchCompleted() throws -> [MapRegion] {
        try fetchAll(status: .complete)
    }

    /// Fetches regions currently downloading
    func fetchDownloading() throws -> [MapRegion] {
        try fetchAll(status: .downloading)
    }

    // MARK: - Update

    /// Updates an existing map region
    @discardableResult
    func update(_ region: MapRegion) throws -> MapRegion {
        try dbPool.write { db in
            var updatedRegion = region
            updatedRegion.updatedAt = Date()
            try updatedRegion.update(db)
            return updatedRegion
        }
    }

    /// Updates download progress
    func updateProgress(
        regionId: Int64,
        downloadedBytes: Int64,
        totalBytes: Int64
    ) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE map_regions
                    SET downloadedBytes = ?, totalBytes = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [downloadedBytes, totalBytes, Date(), regionId]
            )
        }
    }

    /// Updates download status
    func updateStatus(regionId: Int64, status: DownloadStatus, error: String? = nil) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE map_regions
                    SET status = ?, downloadError = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [status.rawValue, error, Date(), regionId]
            )
        }
    }

    /// Marks a region as complete
    func markComplete(regionId: Int64, tileCount: Int64, totalBytes: Int64) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE map_regions
                    SET status = ?, tileCount = ?, downloadedBytes = ?, totalBytes = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [
                    DownloadStatus.complete.rawValue,
                    tileCount,
                    totalBytes,
                    totalBytes,
                    Date(),
                    regionId
                ]
            )
        }
    }

    // MARK: - Delete

    /// Deletes a map region by ID
    func delete(id: Int64) throws {
        try dbPool.write { db in
            _ = try MapRegion.deleteOne(db, key: id)
        }
    }

    /// Deletes a map region
    func delete(_ region: MapRegion) throws {
        guard let id = region.id else { return }
        try delete(id: id)
    }

    // MARK: - Statistics

    /// Returns the total storage used by all regions
    func totalStorageUsed() throws -> Int64 {
        try dbPool.read { db in
            let sum = try Int64.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(downloadedBytes), 0) FROM map_regions WHERE status = ?",
                arguments: [DownloadStatus.complete.rawValue]
            )
            return sum ?? 0
        }
    }

    /// Returns formatted total storage used
    func formattedStorageUsed() throws -> String {
        let bytes = try totalStorageUsed()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Returns the total number of regions
    func count() throws -> Int {
        try dbPool.read { db in
            try MapRegion.fetchCount(db)
        }
    }

    /// Returns the number of completed regions
    func countCompleted() throws -> Int {
        try dbPool.read { db in
            try MapRegion
                .filter(MapRegion.Columns.status == DownloadStatus.complete.rawValue)
                .fetchCount(db)
        }
    }
}
