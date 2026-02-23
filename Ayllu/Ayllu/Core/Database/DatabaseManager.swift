import Foundation
import GRDB

/// Manages the SQLite database using GRDB
@Observable
final class DatabaseManager {
    /// The database connection pool
    let dbPool: DatabasePool

    /// Path to the database file
    let databasePath: String

    /// Initializes the database manager with the default app database
    init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let databaseURL = appSupportURL.appendingPathComponent("ayllu.sqlite")
        databasePath = databaseURL.path

        var config = Configuration()

        // Enable WAL mode for better concurrent access
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        // Enable foreign key constraints
        config.foreignKeysEnabled = true

        dbPool = try DatabasePool(path: databasePath, configuration: config)

        // Run migrations
        try migrator.migrate(dbPool)
    }

    /// Initializes the database manager with a custom path (for testing)
    init(path: String) throws {
        databasePath = path

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        config.foreignKeysEnabled = true

        dbPool = try DatabasePool(path: path, configuration: config)
        try migrator.migrate(dbPool)
    }

    /// Creates an in-memory database (for testing)
    static func inMemory() throws -> DatabaseManager {
        let tempDir = FileManager.default.temporaryDirectory
        let testPath = tempDir.appendingPathComponent(UUID().uuidString + ".sqlite").path
        return try DatabaseManager(path: testPath)
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Always run migrations in order
        migrator.eraseDatabaseOnSchemaChange = false

        // Version 1: Initial schema
        migrator.registerMigration("v1_initial_schema") { db in
            // Projects table
            try db.create(table: "projects") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("startDate", .datetime)
                t.column("endDate", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Waypoints table
            try db.create(table: "waypoints") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("projectId", .integer)
                    .notNull()
                    .references("projects", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("altitude", .double)
                t.column("horizontalAccuracy", .double)
                t.column("verticalAccuracy", .double)
                t.column("heading", .double)
                t.column("speed", .double)
                t.column("tags", .text)  // JSON array
                t.column("customFields", .text)  // JSON object
                t.column("category", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Waypoints indexes
            try db.create(
                index: "waypoints_projectId",
                on: "waypoints",
                columns: ["projectId"]
            )
            try db.create(
                index: "waypoints_coordinates",
                on: "waypoints",
                columns: ["latitude", "longitude"]
            )
            try db.create(
                index: "waypoints_createdAt",
                on: "waypoints",
                columns: ["createdAt"]
            )

            // Photos table
            try db.create(table: "photos") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("projectId", .integer)
                    .notNull()
                    .references("projects", onDelete: .cascade)
                t.column("waypointId", .integer)
                    .references("waypoints", onDelete: .setNull)
                t.column("filePath", .text).notNull()
                t.column("thumbnailPath", .text)
                t.column("caption", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("altitude", .double)
                t.column("heading", .double)
                t.column("timestamp", .datetime).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Photos indexes
            try db.create(
                index: "photos_projectId",
                on: "photos",
                columns: ["projectId"]
            )
            try db.create(
                index: "photos_waypointId",
                on: "photos",
                columns: ["waypointId"]
            )

            // Field notes table
            try db.create(table: "field_notes") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("projectId", .integer)
                    .notNull()
                    .references("projects", onDelete: .cascade)
                t.column("waypointId", .integer)
                    .references("waypoints", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("content", .text).notNull().defaults(to: "")
                t.column("audioFilePath", .text)
                t.column("transcription", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Field notes indexes
            try db.create(
                index: "field_notes_projectId",
                on: "field_notes",
                columns: ["projectId"]
            )
            try db.create(
                index: "field_notes_waypointId",
                on: "field_notes",
                columns: ["waypointId"]
            )

            // Tracks table
            try db.create(table: "tracks") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("projectId", .integer)
                    .notNull()
                    .references("projects", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("startTime", .datetime).notNull()
                t.column("endTime", .datetime)
                t.column("distance", .double)
                t.column("duration", .double)
                t.column("elevationGain", .double)
                t.column("elevationLoss", .double)
                t.column("isRecording", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Tracks indexes
            try db.create(
                index: "tracks_projectId",
                on: "tracks",
                columns: ["projectId"]
            )

            // Track points table
            try db.create(table: "track_points") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("trackId", .integer)
                    .notNull()
                    .references("tracks", onDelete: .cascade)
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("altitude", .double)
                t.column("horizontalAccuracy", .double)
                t.column("verticalAccuracy", .double)
                t.column("speed", .double)
                t.column("heading", .double)
                t.column("timestamp", .datetime).notNull()
                t.column("segmentIndex", .integer).notNull().defaults(to: 0)
            }

            // Track points indexes
            try db.create(
                index: "track_points_trackId",
                on: "track_points",
                columns: ["trackId"]
            )
            try db.create(
                index: "track_points_timestamp",
                on: "track_points",
                columns: ["timestamp"]
            )

            // Map regions table
            try db.create(table: "map_regions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("northLatitude", .double).notNull()
                t.column("southLatitude", .double).notNull()
                t.column("eastLongitude", .double).notNull()
                t.column("westLongitude", .double).notNull()
                t.column("minZoom", .integer).notNull().defaults(to: 1)
                t.column("maxZoom", .integer).notNull().defaults(to: 16)
                t.column("tileCount", .integer)
                t.column("downloadedBytes", .integer)
                t.column("totalBytes", .integer)
                t.column("status", .text).notNull().defaults(to: "pending")
                t.column("downloadError", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }

        return migrator
    }

    // MARK: - Database Statistics

    /// Returns the size of the database file in bytes
    func databaseSize() -> Int64 {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: databasePath),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    /// Returns formatted database size
    func formattedDatabaseSize() -> String {
        ByteCountFormatter.string(fromByteCount: databaseSize(), countStyle: .file)
    }
}
