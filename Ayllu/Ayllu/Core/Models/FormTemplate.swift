import Foundation
import GRDB

/// A form template associated with a record type, defining the fields to collect
struct FormTemplate: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var recordTypeId: Int64
    var name: String
    var description: String?
    var version: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        recordTypeId: Int64,
        name: String,
        description: String? = nil,
        version: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recordTypeId = recordTypeId
        self.name = name
        self.description = description
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB Conformance

extension FormTemplate: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "form_templates"

    // Associations
    static let recordType = belongsTo(RecordType.self)
    static let fields = hasMany(FormField.self)

    enum Columns: String, ColumnExpression {
        case id, recordTypeId, name, description
        case version, createdAt, updatedAt
    }

    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
