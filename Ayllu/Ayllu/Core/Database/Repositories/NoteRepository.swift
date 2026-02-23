import Foundation
import GRDB

/// Repository for FieldNote CRUD operations
struct NoteRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    /// Creates a new field note and returns it with the assigned ID
    @discardableResult
    func create(_ note: FieldNote) throws -> FieldNote {
        try dbPool.write { db in
            var newNote = note
            try newNote.insert(db)
            return newNote
        }
    }

    // MARK: - Read

    /// Fetches all field notes, optionally filtered
    func fetchAll(
        projectId: Int64? = nil,
        waypointId: Int64? = nil,
        searchTerm: String? = nil,
        hasAudio: Bool? = nil
    ) throws -> [FieldNote] {
        try dbPool.read { db in
            var query = FieldNote.all().order(FieldNote.Columns.updatedAt.desc)

            if let projectId = projectId {
                query = query.filter(FieldNote.Columns.projectId == projectId)
            }

            if let waypointId = waypointId {
                query = query.filter(FieldNote.Columns.waypointId == waypointId)
            }

            if let search = searchTerm, !search.isEmpty {
                let pattern = "%\(search)%"
                query = query.filter(
                    FieldNote.Columns.title.like(pattern) ||
                    FieldNote.Columns.content.like(pattern) ||
                    FieldNote.Columns.transcription.like(pattern)
                )
            }

            if let hasAudio = hasAudio {
                if hasAudio {
                    query = query.filter(FieldNote.Columns.audioFilePath != nil)
                } else {
                    query = query.filter(FieldNote.Columns.audioFilePath == nil)
                }
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches a field note by ID
    func fetchById(_ id: Int64) throws -> FieldNote? {
        try dbPool.read { db in
            try FieldNote.fetchOne(db, key: id)
        }
    }

    /// Fetches notes linked to a waypoint
    func fetchForWaypoint(_ waypointId: Int64) throws -> [FieldNote] {
        try fetchAll(waypointId: waypointId)
    }

    // MARK: - Update

    /// Updates an existing field note
    @discardableResult
    func update(_ note: FieldNote) throws -> FieldNote {
        try dbPool.write { db in
            var updatedNote = note
            updatedNote.updatedAt = Date()
            try updatedNote.update(db)
            return updatedNote
        }
    }

    /// Links a note to a waypoint
    func linkToWaypoint(noteId: Int64, waypointId: Int64?) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE field_notes SET waypointId = ?, updatedAt = ? WHERE id = ?",
                arguments: [waypointId, Date(), noteId]
            )
        }
    }

    /// Updates the transcription for a note
    func updateTranscription(noteId: Int64, transcription: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE field_notes SET transcription = ?, updatedAt = ? WHERE id = ?",
                arguments: [transcription, Date(), noteId]
            )
        }
    }

    // MARK: - Delete

    /// Deletes a field note by ID
    func delete(id: Int64) throws {
        try dbPool.write { db in
            _ = try FieldNote.deleteOne(db, key: id)
        }
    }

    /// Deletes a field note
    func delete(_ note: FieldNote) throws {
        guard let id = note.id else { return }
        try delete(id: id)
    }

    /// Deletes all notes for a project
    func deleteAll(projectId: Int64) throws {
        try dbPool.write { db in
            _ = try FieldNote
                .filter(FieldNote.Columns.projectId == projectId)
                .deleteAll(db)
        }
    }

    // MARK: - Count

    /// Returns the number of notes for a project
    func countForProject(_ projectId: Int64) throws -> Int {
        try dbPool.read { db in
            try FieldNote
                .filter(FieldNote.Columns.projectId == projectId)
                .fetchCount(db)
        }
    }

    /// Returns the total number of notes
    func count() throws -> Int {
        try dbPool.read { db in
            try FieldNote.fetchCount(db)
        }
    }

    /// Returns the number of notes with audio recordings
    func countWithAudio() throws -> Int {
        try dbPool.read { db in
            try FieldNote
                .filter(FieldNote.Columns.audioFilePath != nil)
                .fetchCount(db)
        }
    }
}
