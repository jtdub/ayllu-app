import Foundation
import GRDB

/// A field note with optional voice recording and transcription
struct FieldNote: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var projectId: Int64
    var waypointId: Int64?
    var title: String
    var content: String
    var audioFilePath: String?
    var transcription: String?
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        projectId: Int64,
        waypointId: Int64? = nil,
        title: String,
        content: String = "",
        audioFilePath: String? = nil,
        transcription: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.waypointId = waypointId
        self.title = title
        self.content = content
        self.audioFilePath = audioFilePath
        self.transcription = transcription
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Whether this note has an associated audio recording
    var hasAudio: Bool {
        audioFilePath != nil
    }

    /// Whether this note is linked to a waypoint
    var isLinkedToWaypoint: Bool {
        waypointId != nil
    }

    /// Combined text content (content + transcription)
    var fullText: String {
        if let transcription = transcription, !transcription.isEmpty {
            if content.isEmpty {
                return transcription
            }
            return "\(content)\n\n[Transcription]\n\(transcription)"
        }
        return content
    }
}

// MARK: - GRDB Conformance

extension FieldNote: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "field_notes"

    // Define associations
    static let project = belongsTo(Project.self)
    static let waypoint = belongsTo(Waypoint.self)

    enum Columns: String, ColumnExpression {
        case id, projectId, waypointId
        case title, content
        case audioFilePath, transcription
        case latitude, longitude
        case createdAt, updatedAt
    }

    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
