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

    init(
        id: Int64? = nil,
        name: String,
        description: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
}
