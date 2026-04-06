import Foundation
import GRDB
import CoreLocation

/// A hierarchical data record (e.g., a Site, Trench, Context, or Artifact)
struct Record: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var projectId: Int64
    var recordTypeId: Int64
    var parentRecordId: Int64?
    var name: String
    var description: String?
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var formData: [String: String]
    var formTemplateVersion: Int?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var isDeleted: Bool {
        deletedAt != nil
    }

    init(
        id: Int64? = nil,
        projectId: Int64,
        recordTypeId: Int64,
        parentRecordId: Int64? = nil,
        name: String,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        formData: [String: String] = [:],
        formTemplateVersion: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.recordTypeId = recordTypeId
        self.parentRecordId = parentRecordId
        self.name = name
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.formData = formData
        self.formTemplateVersion = formTemplateVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Returns a CLLocationCoordinate2D if both lat/lon are set
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - GRDB Conformance

extension Record: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "records"

    // Associations
    static let project = belongsTo(Project.self)
    static let recordType = belongsTo(RecordType.self)
    static let parentRecord = belongsTo(Record.self, key: "parentRecord", using: ForeignKey(["parentRecordId"]))
    static let childRecords = hasMany(Record.self, key: "childRecords", using: ForeignKey(["parentRecordId"]))
    static let geometries = hasMany(Geometry.self)

    enum Columns: String, ColumnExpression {
        case id, projectId, recordTypeId, parentRecordId
        case name, description
        case latitude, longitude, altitude
        case formData, formTemplateVersion
        case createdAt, updatedAt, deletedAt
    }

    init(row: Row) throws {
        id = row[Columns.id]
        projectId = row[Columns.projectId]
        recordTypeId = row[Columns.recordTypeId]
        parentRecordId = row[Columns.parentRecordId]
        name = row[Columns.name]
        description = row[Columns.description]
        latitude = row[Columns.latitude]
        longitude = row[Columns.longitude]
        altitude = row[Columns.altitude]
        formTemplateVersion = row[Columns.formTemplateVersion]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]

        // Decode JSON formData
        if let data = row[Columns.formData] as? Data {
            formData = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        } else if let string = row[Columns.formData] as? String,
                  let data = string.data(using: .utf8) {
            formData = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        } else {
            formData = [:]
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.projectId] = projectId
        container[Columns.recordTypeId] = recordTypeId
        container[Columns.parentRecordId] = parentRecordId
        container[Columns.name] = name
        container[Columns.description] = description
        container[Columns.latitude] = latitude
        container[Columns.longitude] = longitude
        container[Columns.altitude] = altitude
        container[Columns.formTemplateVersion] = formTemplateVersion
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt

        if let data = try? JSONEncoder().encode(formData) {
            container[Columns.formData] = String(data: data, encoding: .utf8)
        }
    }

    mutating func willInsert(_ db: Database) throws {
        createdAt = Date()
        updatedAt = Date()
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
