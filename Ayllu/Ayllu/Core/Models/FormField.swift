import Foundation
import GRDB

/// The type of input a form field accepts
enum FieldType: String, Codable, CaseIterable {
    case text
    case textArea
    case number
    case dropdown
    case multiSelect
    case date
    case photo
    case gpsCoordinates
    case toggle

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .textArea: return "Text Area"
        case .number: return "Number"
        case .dropdown: return "Dropdown"
        case .multiSelect: return "Multi-Select"
        case .date: return "Date"
        case .photo: return "Photo"
        case .gpsCoordinates: return "GPS Coordinates"
        case .toggle: return "Toggle"
        }
    }

    var iconName: String {
        switch self {
        case .text: return "textformat"
        case .textArea: return "text.alignleft"
        case .number: return "number"
        case .dropdown: return "chevron.down.circle"
        case .multiSelect: return "checklist"
        case .date: return "calendar"
        case .photo: return "camera"
        case .gpsCoordinates: return "location"
        case .toggle: return "switch.2"
        }
    }
}

/// Keys for the `validationRules` dictionary on `FormField`
enum ValidationRuleKey {
    static let min = "min"
    static let max = "max"
    static let minLength = "minLength"
    static let maxLength = "maxLength"
    static let pattern = "pattern"
    static let patternMessage = "patternMessage"
    static let noFutureDates = "noFutureDates"
    static let minDate = "minDate"
    static let maxDate = "maxDate"
}

/// A single field within a form template
struct FormField: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var formTemplateId: Int64
    var name: String
    var label: String
    var fieldType: FieldType
    var isRequired: Bool
    var defaultValue: String?
    var options: [String]
    var validationRules: [String: String]
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        formTemplateId: Int64,
        name: String,
        label: String,
        fieldType: FieldType = .text,
        isRequired: Bool = false,
        defaultValue: String? = nil,
        options: [String] = [],
        validationRules: [String: String] = [:],
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.formTemplateId = formTemplateId
        self.name = name
        self.label = label
        self.fieldType = fieldType
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.options = options
        self.validationRules = validationRules
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB Conformance

extension FormField: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "form_fields"

    // Associations
    static let formTemplate = belongsTo(FormTemplate.self)

    enum Columns: String, ColumnExpression {
        case id, formTemplateId, name, label
        case fieldType, isRequired, defaultValue
        case options, validationRules, sortOrder
        case createdAt, updatedAt
    }

    init(row: Row) throws {
        id = row[Columns.id]
        formTemplateId = row[Columns.formTemplateId]
        name = row[Columns.name]
        label = row[Columns.label]
        isRequired = row[Columns.isRequired]
        defaultValue = row[Columns.defaultValue]
        sortOrder = row[Columns.sortOrder]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]

        // Decode fieldType
        if let typeString = row[Columns.fieldType] as? String {
            fieldType = FieldType(rawValue: typeString) ?? .text
        } else {
            fieldType = .text
        }

        // Decode JSON options
        if let optionsData = row[Columns.options] as? Data {
            options = (try? JSONDecoder().decode([String].self, from: optionsData)) ?? []
        } else if let optionsString = row[Columns.options] as? String,
                  let optionsData = optionsString.data(using: .utf8) {
            options = (try? JSONDecoder().decode([String].self, from: optionsData)) ?? []
        } else {
            options = []
        }

        // Decode JSON validationRules
        if let rulesData = row[Columns.validationRules] as? Data {
            validationRules = (try? JSONDecoder().decode([String: String].self, from: rulesData)) ?? [:]
        } else if let rulesString = row[Columns.validationRules] as? String,
                  let rulesData = rulesString.data(using: .utf8) {
            validationRules = (try? JSONDecoder().decode([String: String].self, from: rulesData)) ?? [:]
        } else {
            validationRules = [:]
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.formTemplateId] = formTemplateId
        container[Columns.name] = name
        container[Columns.label] = label
        container[Columns.fieldType] = fieldType.rawValue
        container[Columns.isRequired] = isRequired
        container[Columns.defaultValue] = defaultValue
        container[Columns.sortOrder] = sortOrder
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt

        if let optionsData = try? JSONEncoder().encode(options) {
            container[Columns.options] = String(data: optionsData, encoding: .utf8)
        }
        if let rulesData = try? JSONEncoder().encode(validationRules) {
            container[Columns.validationRules] = String(data: rulesData, encoding: .utf8)
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
