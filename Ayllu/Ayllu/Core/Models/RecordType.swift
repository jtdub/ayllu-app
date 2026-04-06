import Foundation
import GRDB

/// Defines a type of record within a project (e.g., "Site", "Trench", "Context")
/// Record types can form a hierarchy via parentTypeId
struct RecordType: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var projectId: Int64
    var name: String
    var description: String?
    var parentTypeId: Int64?
    var iconName: String?
    var color: String?
    var sortOrder: Int
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
        parentTypeId: Int64? = nil,
        iconName: String? = nil,
        color: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.description = description
        self.parentTypeId = parentTypeId
        self.iconName = iconName
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

// MARK: - GRDB Conformance

extension RecordType: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "record_types"

    // Associations
    static let project = belongsTo(Project.self)
    static let parentType = belongsTo(RecordType.self, key: "parentType", using: ForeignKey(["parentTypeId"]))
    static let childTypes = hasMany(RecordType.self, key: "childTypes", using: ForeignKey(["parentTypeId"]))
    static let formTemplate = hasOne(FormTemplate.self)
    static let records = hasMany(Record.self)

    enum Columns: String, ColumnExpression {
        case id, projectId, name, description
        case parentTypeId, iconName, color, sortOrder
        case createdAt, updatedAt, deletedAt
    }

    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
