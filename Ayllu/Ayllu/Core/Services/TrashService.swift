import Foundation
import GRDB

/// Service for managing soft-deleted items (trash)
@Observable
final class TrashService {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    // MARK: - Fetch Deleted Items

    func fetchDeletedProjects() throws -> [Project] {
        try dbPool.read { db in
            try Project.filter(Column("deletedAt") != nil)
                .order(Column("deletedAt").desc)
                .fetchAll(db)
        }
    }

    func fetchDeletedWaypoints() throws -> [Waypoint] {
        try dbPool.read { db in
            try Waypoint.filter(Column("deletedAt") != nil)
                .order(Column("deletedAt").desc)
                .fetchAll(db)
        }
    }

    func fetchDeletedNotes() throws -> [FieldNote] {
        try dbPool.read { db in
            try FieldNote.filter(Column("deletedAt") != nil)
                .order(Column("deletedAt").desc)
                .fetchAll(db)
        }
    }

    func fetchDeletedPhotos() throws -> [Photo] {
        try dbPool.read { db in
            try Photo.filter(Column("deletedAt") != nil)
                .order(Column("deletedAt").desc)
                .fetchAll(db)
        }
    }

    func fetchDeletedTracks() throws -> [Track] {
        try dbPool.read { db in
            try Track.filter(Column("deletedAt") != nil)
                .order(Column("deletedAt").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Restore Items

    func restoreProject(_ project: Project) throws {
        var updatedProject = project
        updatedProject.deletedAt = nil
        try dbPool.write { db in
            try updatedProject.update(db)
        }
    }

    func restoreWaypoint(_ waypoint: Waypoint) throws {
        var updatedWaypoint = waypoint
        updatedWaypoint.deletedAt = nil
        try dbPool.write { db in
            try updatedWaypoint.update(db)
        }
    }

    func restoreNote(_ note: FieldNote) throws {
        var updatedNote = note
        updatedNote.deletedAt = nil
        try dbPool.write { db in
            try updatedNote.update(db)
        }
    }

    func restorePhoto(_ photo: Photo) throws {
        var updatedPhoto = photo
        updatedPhoto.deletedAt = nil
        try dbPool.write { db in
            try updatedPhoto.update(db)
        }
    }

    func restoreTrack(_ track: Track) throws {
        var updatedTrack = track
        updatedTrack.deletedAt = nil
        try dbPool.write { db in
            try updatedTrack.update(db)
        }
    }

    // MARK: - Permanent Delete

    func permanentlyDeleteProject(_ project: Project) throws {
        guard let id = project.id else { return }
        try dbPool.write { db in
            try Project.deleteOne(db, key: id)
        }
    }

    func permanentlyDeleteWaypoint(_ waypoint: Waypoint) throws {
        guard let id = waypoint.id else { return }
        try dbPool.write { db in
            try Waypoint.deleteOne(db, key: id)
        }
    }

    func permanentlyDeleteNote(_ note: FieldNote) throws {
        guard let id = note.id else { return }
        try dbPool.write { db in
            try FieldNote.deleteOne(db, key: id)
        }
    }

    func permanentlyDeletePhoto(_ photo: Photo) throws {
        guard let id = photo.id else { return }
        try dbPool.write { db in
            try Photo.deleteOne(db, key: id)
        }
    }

    func permanentlyDeleteTrack(_ track: Track) throws {
        guard let id = track.id else { return }
        try dbPool.write { db in
            try Track.deleteOne(db, key: id)
        }
    }

    // MARK: - Auto-Purge

    /// Permanently deletes items that have been in trash for more than 30 days
    func purgeOldDeletedItems() throws {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        try dbPool.write { db in
            // Purge projects
            try Project.filter(Column("deletedAt") < thirtyDaysAgo).deleteAll(db)

            // Purge waypoints
            try Waypoint.filter(Column("deletedAt") < thirtyDaysAgo).deleteAll(db)

            // Purge notes
            try FieldNote.filter(Column("deletedAt") < thirtyDaysAgo).deleteAll(db)

            // Purge photos
            try Photo.filter(Column("deletedAt") < thirtyDaysAgo).deleteAll(db)

            // Purge tracks
            try Track.filter(Column("deletedAt") < thirtyDaysAgo).deleteAll(db)
        }
    }

    /// Gets count of items in trash
    func getTrashCount() throws -> Int {
        try dbPool.read { db in
            let projectCount = try Project.filter(Column("deletedAt") != nil).fetchCount(db)
            let waypointCount = try Waypoint.filter(Column("deletedAt") != nil).fetchCount(db)
            let noteCount = try FieldNote.filter(Column("deletedAt") != nil).fetchCount(db)
            let photoCount = try Photo.filter(Column("deletedAt") != nil).fetchCount(db)
            let trackCount = try Track.filter(Column("deletedAt") != nil).fetchCount(db)

            return projectCount + waypointCount + noteCount + photoCount + trackCount
        }
    }
}
