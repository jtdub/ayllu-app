import Foundation
import GRDB

/// A research project that contains waypoints, notes, and other field data
struct Project: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var name: String
    var description: String?
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var isDeleted: Bool {
        deletedAt != nil
    }

    init(
        id: Int64? = nil,
        name: String,
        description: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

// MARK: - GRDB Conformance

extension Project: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "projects"

    // Define associations
    static let waypoints = hasMany(Waypoint.self)
    static let fieldNotes = hasMany(FieldNote.self)
    static let photos = hasMany(Photo.self)
    static let tracks = hasMany(Track.self)
    static let recordTypes = hasMany(RecordType.self)
    static let records = hasMany(Record.self)
    static let geometries = hasMany(Geometry.self)

    // Set timestamps on insert
    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    // Capture the auto-generated rowID
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Project Statistics

struct ProjectStatistics {
    let waypointCount: Int
    let noteCount: Int
    let photoCount: Int
    let trackCount: Int
    let recordCount: Int
    let geometryCount: Int

    init(
        waypointCount: Int = 0,
        noteCount: Int = 0,
        photoCount: Int = 0,
        trackCount: Int = 0,
        recordCount: Int = 0,
        geometryCount: Int = 0
    ) {
        self.waypointCount = waypointCount
        self.noteCount = noteCount
        self.photoCount = photoCount
        self.trackCount = trackCount
        self.recordCount = recordCount
        self.geometryCount = geometryCount
    }
}
