import Foundation
import GRDB
import CoreLocation

/// A GPS waypoint with coordinates and metadata
struct Waypoint: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var projectId: Int64
    var name: String
    var description: String?
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double?
    var verticalAccuracy: Double?
    var heading: Double?
    var speed: Double?
    var tags: [String]
    var customFields: [String: String]
    var category: WaypointCategory?
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
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double? = nil,
        verticalAccuracy: Double? = nil,
        heading: Double? = nil,
        speed: Double? = nil,
        tags: [String] = [],
        customFields: [String: String] = [:],
        category: WaypointCategory? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.heading = heading
        self.speed = speed
        self.tags = tags
        self.customFields = customFields
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// Returns a CLLocationCoordinate2D for map display
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Returns a CLLocation for distance calculations
    var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy ?? -1,
            verticalAccuracy: verticalAccuracy ?? -1,
            timestamp: createdAt
        )
    }
}

// MARK: - Waypoint Category

enum WaypointCategory: String, Codable, CaseIterable {
    case site = "site"
    case feature = "feature"
    case artifact = "artifact"
    case sample = "sample"
    case photoPoint = "photo_point"
    case controlPoint = "control_point"
    case datum = "datum"
    case observation = "observation"
    case specimen = "specimen"
    case transectMarker = "transect_marker"
    case other = "other"

    var displayName: String {
        switch self {
        case .site: return "Site"
        case .feature: return "Feature"
        case .artifact: return "Artifact"
        case .sample: return "Sample"
        case .photoPoint: return "Photo Point"
        case .controlPoint: return "Control Point"
        case .datum: return "Datum"
        case .observation: return "Observation"
        case .specimen: return "Specimen"
        case .transectMarker: return "Transect Marker"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .site: return "building.columns"
        case .feature: return "square.on.square"
        case .artifact: return "archivebox"
        case .sample: return "testtube.2"
        case .photoPoint: return "camera"
        case .controlPoint: return "scope"
        case .datum: return "target"
        case .observation: return "eye"
        case .specimen: return "leaf"
        case .transectMarker: return "line.diagonal"
        case .other: return "mappin"
        }
    }
}

// MARK: - GRDB Conformance

extension Waypoint: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "waypoints"

    // Define associations
    static let project = belongsTo(Project.self)
    static let fieldNotes = hasMany(FieldNote.self)
    static let photos = hasMany(Photo.self)

    // Custom encoding for JSON fields
    enum Columns: String, ColumnExpression {
        case id, projectId, name, description
        case latitude, longitude, altitude
        case horizontalAccuracy, verticalAccuracy
        case heading, speed
        case tags, customFields, category
        case createdAt, updatedAt
    }

    init(row: Row) throws {
        id = row[Columns.id]
        projectId = row[Columns.projectId]
        name = row[Columns.name]
        description = row[Columns.description]
        latitude = row[Columns.latitude]
        longitude = row[Columns.longitude]
        altitude = row[Columns.altitude]
        horizontalAccuracy = row[Columns.horizontalAccuracy]
        verticalAccuracy = row[Columns.verticalAccuracy]
        heading = row[Columns.heading]
        speed = row[Columns.speed]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]

        // Decode JSON fields
        if let tagsData = row[Columns.tags] as? Data {
            tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        } else if let tagsString = row[Columns.tags] as? String,
                  let tagsData = tagsString.data(using: .utf8) {
            tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        } else {
            tags = []
        }

        if let customFieldsData = row[Columns.customFields] as? Data {
            customFields = (try? JSONDecoder().decode([String: String].self, from: customFieldsData)) ?? [:]
        } else if let customFieldsString = row[Columns.customFields] as? String,
                  let customFieldsData = customFieldsString.data(using: .utf8) {
            customFields = (try? JSONDecoder().decode([String: String].self, from: customFieldsData)) ?? [:]
        } else {
            customFields = [:]
        }

        if let categoryString = row[Columns.category] as? String {
            category = WaypointCategory(rawValue: categoryString)
        } else {
            category = nil
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.projectId] = projectId
        container[Columns.name] = name
        container[Columns.description] = description
        container[Columns.latitude] = latitude
        container[Columns.longitude] = longitude
        container[Columns.altitude] = altitude
        container[Columns.horizontalAccuracy] = horizontalAccuracy
        container[Columns.verticalAccuracy] = verticalAccuracy
        container[Columns.heading] = heading
        container[Columns.speed] = speed
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.category] = category?.rawValue

        // Encode JSON fields
        if let tagsData = try? JSONEncoder().encode(tags) {
            container[Columns.tags] = String(data: tagsData, encoding: .utf8)
        }
        if let customFieldsData = try? JSONEncoder().encode(customFields) {
            container[Columns.customFields] = String(data: customFieldsData, encoding: .utf8)
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
