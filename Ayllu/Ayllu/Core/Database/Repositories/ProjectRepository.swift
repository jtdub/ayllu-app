import Foundation
import GRDB

/// Repository for Project CRUD operations
struct ProjectRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    /// Creates a new project and returns it with the assigned ID
    @discardableResult
    func create(_ project: Project) throws -> Project {
        try dbPool.write { db in
            var newProject = project
            try newProject.insert(db)
            return newProject
        }
    }

    // MARK: - Read

    /// Fetches all projects, optionally filtered by search term (excludes soft-deleted by default)
    func fetchAll(searchTerm: String? = nil, includeDeleted: Bool = false) throws -> [Project] {
        try dbPool.read { db in
            var query = Project.all().order(Project.Columns.updatedAt.desc)

            // Filter out soft-deleted items unless explicitly requested
            if !includeDeleted {
                query = query.filter(Column("deletedAt") == nil)
            }

            if let search = searchTerm, !search.isEmpty {
                let pattern = "%\(search)%"
                query = query.filter(
                    Project.Columns.name.like(pattern) ||
                    Project.Columns.description.like(pattern)
                )
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches a project by ID
    func fetchById(_ id: Int64) throws -> Project? {
        try dbPool.read { db in
            try Project.fetchOne(db, key: id)
        }
    }

    // MARK: - Update

    /// Updates an existing project
    @discardableResult
    func update(_ project: Project) throws -> Project {
        try dbPool.write { db in
            var updatedProject = project
            updatedProject.updatedAt = Date()
            try updatedProject.update(db)
            return updatedProject
        }
    }

    // MARK: - Delete

    /// Soft deletes a project by ID (marks as deleted but keeps in database)
    func delete(id: Int64) throws {
        try dbPool.write { db in
            guard var project = try Project.fetchOne(db, key: id) else { return }
            project.deletedAt = Date()
            try project.update(db)
        }
    }

    /// Soft deletes a project (marks as deleted but keeps in database)
    func delete(_ project: Project) throws {
        guard let id = project.id else { return }
        try delete(id: id)
    }

    /// Permanently deletes a project by ID (hard delete, cascades to waypoints, notes, photos, tracks)
    func permanentlyDelete(id: Int64) throws {
        try dbPool.write { db in
            _ = try Project.deleteOne(db, key: id)
        }
    }

    // MARK: - Statistics

    /// Returns statistics for a project
    func statistics(for projectId: Int64) throws -> ProjectStatistics {
        try dbPool.read { db in
            let waypointCount = try Waypoint
                .filter(Waypoint.Columns.projectId == projectId)
                .fetchCount(db)

            let noteCount = try FieldNote
                .filter(FieldNote.Columns.projectId == projectId)
                .fetchCount(db)

            let photoCount = try Photo
                .filter(Photo.Columns.projectId == projectId)
                .fetchCount(db)

            let trackCount = try Track
                .filter(Track.Columns.projectId == projectId)
                .fetchCount(db)

            return ProjectStatistics(
                waypointCount: waypointCount,
                noteCount: noteCount,
                photoCount: photoCount,
                trackCount: trackCount
            )
        }
    }

    /// Returns the total number of projects
    func count() throws -> Int {
        try dbPool.read { db in
            try Project.fetchCount(db)
        }
    }
}

// MARK: - Column Definitions

extension Project {
    enum Columns: String, ColumnExpression {
        case id, name, description
        case startDate, endDate
        case createdAt, updatedAt
    }
}
