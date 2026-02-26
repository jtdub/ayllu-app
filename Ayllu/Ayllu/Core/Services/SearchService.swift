import Foundation
import GRDB

/// Service for searching across all data types
@Observable
final class SearchService {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    /// Performs a search across all data types
    /// - Parameter query: The search text
    /// - Returns: Search results grouped by type
    func search(_ query: String) throws -> SearchResults {
        guard !query.isEmpty else {
            return SearchResults()
        }

        let searchPattern = "%\(query)%"

        return try dbPool.read { db in
            // Search projects
            let projects = try Project.filter(
                Column("name").like(searchPattern) ||
                Column("description").like(searchPattern)
            )
            .order(Column("name"))
            .fetchAll(db)

            // Search waypoints
            let waypoints = try Waypoint.filter(
                Column("name").like(searchPattern) ||
                Column("description").like(searchPattern) ||
                Column("tags").like(searchPattern)
            )
            .order(Column("createdAt").desc)
            .fetchAll(db)

            // Search field notes
            let notes = try FieldNote.filter(
                Column("title").like(searchPattern) ||
                Column("content").like(searchPattern) ||
                Column("transcription").like(searchPattern)
            )
            .order(Column("createdAt").desc)
            .fetchAll(db)

            return SearchResults(
                projects: projects,
                waypoints: waypoints,
                notes: notes,
                query: query
            )
        }
    }
}

// MARK: - Search Results

struct SearchResults {
    let projects: [Project]
    let waypoints: [Waypoint]
    let notes: [FieldNote]
    let query: String

    init(
        projects: [Project] = [],
        waypoints: [Waypoint] = [],
        notes: [FieldNote] = [],
        query: String = ""
    ) {
        self.projects = projects
        self.waypoints = waypoints
        self.notes = notes
        self.query = query
    }

    var isEmpty: Bool {
        projects.isEmpty && waypoints.isEmpty && notes.isEmpty
    }

    var totalCount: Int {
        projects.count + waypoints.count + notes.count
    }
}

// MARK: - Search Result Item

enum SearchResultItem: Identifiable, Hashable {
    case project(Project)
    case waypoint(Waypoint)
    case note(FieldNote)

    var id: String {
        switch self {
        case .project(let project):
            return "project-\(project.id ?? 0)"
        case .waypoint(let waypoint):
            return "waypoint-\(waypoint.id ?? 0)"
        case .note(let note):
            return "note-\(note.id ?? 0)"
        }
    }

    var title: String {
        switch self {
        case .project(let project):
            return project.name
        case .waypoint(let waypoint):
            return waypoint.name
        case .note(let note):
            return note.title
        }
    }

    var subtitle: String? {
        switch self {
        case .project(let project):
            return project.description
        case .waypoint(let waypoint):
            return waypoint.description
        case .note(let note):
            return note.content
        }
    }

    var iconName: String {
        switch self {
        case .project:
            return "folder.fill"
        case .waypoint:
            return "mappin.circle.fill"
        case .note:
            return "note.text"
        }
    }

    var typeName: String {
        switch self {
        case .project:
            return "Project"
        case .waypoint:
            return "Waypoint"
        case .note:
            return "Note"
        }
    }
}
