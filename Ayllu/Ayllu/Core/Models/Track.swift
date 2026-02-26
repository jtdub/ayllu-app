import Foundation
import GRDB

/// A GPS track (breadcrumb trail) recorded during field work
struct Track: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var projectId: Int64
    var name: String
    var description: String?
    var startTime: Date
    var endTime: Date?
    var distance: Double?  // in meters
    var duration: TimeInterval?  // in seconds
    var elevationGain: Double?  // in meters
    var elevationLoss: Double?  // in meters
    var isRecording: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var isDeleted: Bool {
        deletedAt != nil
    }

    init(
        id: Int64? = nil,
        projectId: Int64,
        name: String,
        description: String? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        distance: Double? = nil,
        duration: TimeInterval? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        isRecording: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.duration = duration
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.isRecording = isRecording
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Formatted distance string
    var formattedDistance: String {
        guard let distance = distance else { return "—" }
        if distance < 1_000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.2f km", distance / 1_000)
        }
    }

    /// Formatted duration string
    var formattedDuration: String {
        guard let duration = duration else { return "—" }
        let hours = Int(duration) / 3_600
        let minutes = (Int(duration) % 3_600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - GRDB Conformance

extension Track: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "tracks"

    // Define associations
    static let project = belongsTo(Project.self)
    static let trackPoints = hasMany(TrackPoint.self)

    enum Columns: String, ColumnExpression {
        case id, projectId, name, description
        case startTime, endTime
        case distance, duration
        case elevationGain, elevationLoss
        case isRecording
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
