import Foundation
import GRDB

/// V3 Migration: Records, forms, and geometries tables
enum V3RecordsFormsGeometries {
    static func migrate(_ db: Database) throws {
        try createRecordTypesAndForms(db)
        try createRecordsTable(db)
        try createGeometryTables(db)
    }

    private static func createRecordTypesAndForms(_ db: Database) throws {
        try db.create(table: "record_types") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("projectId", .integer)
                .notNull()
                .references("projects", onDelete: .cascade)
            t.column("name", .text).notNull()
            t.column("description", .text)
            t.column("parentTypeId", .integer)
                .references("record_types", onDelete: .setNull)
            t.column("iconName", .text)
            t.column("color", .text)
            t.column("sortOrder", .integer).notNull().defaults(to: 0)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
            t.column("deletedAt", .datetime)
        }

        try db.create(index: "record_types_projectId", on: "record_types", columns: ["projectId"])
        try db.create(index: "record_types_parentTypeId", on: "record_types", columns: ["parentTypeId"])

        try db.create(table: "form_templates") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("recordTypeId", .integer)
                .notNull()
                .unique()
                .references("record_types", onDelete: .cascade)
            t.column("name", .text).notNull()
            t.column("description", .text)
            t.column("version", .integer).notNull().defaults(to: 1)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }

        try db.create(index: "form_templates_recordTypeId", on: "form_templates", columns: ["recordTypeId"])

        try db.create(table: "form_fields") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("formTemplateId", .integer)
                .notNull()
                .references("form_templates", onDelete: .cascade)
            t.column("name", .text).notNull()
            t.column("label", .text).notNull()
            t.column("fieldType", .text).notNull()
            t.column("isRequired", .boolean).notNull().defaults(to: false)
            t.column("defaultValue", .text)
            t.column("options", .text)
            t.column("validationRules", .text)
            t.column("sortOrder", .integer).notNull().defaults(to: 0)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }

        try db.create(index: "form_fields_formTemplateId", on: "form_fields", columns: ["formTemplateId"])
    }

    private static func createRecordsTable(_ db: Database) throws {
        try db.create(table: "records") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("projectId", .integer)
                .notNull()
                .references("projects", onDelete: .cascade)
            t.column("recordTypeId", .integer)
                .notNull()
                .references("record_types", onDelete: .restrict)
            t.column("parentRecordId", .integer)
                .references("records", onDelete: .cascade)
            t.column("name", .text).notNull()
            t.column("description", .text)
            t.column("latitude", .double)
            t.column("longitude", .double)
            t.column("altitude", .double)
            t.column("formData", .text)
            t.column("formTemplateVersion", .integer)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
            t.column("deletedAt", .datetime)
        }

        try db.create(index: "records_projectId", on: "records", columns: ["projectId"])
        try db.create(index: "records_recordTypeId", on: "records", columns: ["recordTypeId"])
        try db.create(index: "records_parentRecordId", on: "records", columns: ["parentRecordId"])
        try db.create(index: "records_deletedAt", on: "records", columns: ["deletedAt"])
        try db.create(index: "records_coordinates", on: "records", columns: ["latitude", "longitude"])
    }

    private static func createGeometryTables(_ db: Database) throws {
        try db.create(table: "geometries") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("projectId", .integer)
                .notNull()
                .references("projects", onDelete: .cascade)
            t.column("recordId", .integer)
                .references("records", onDelete: .setNull)
            t.column("name", .text).notNull()
            t.column("description", .text)
            t.column("geometryType", .text).notNull()
            t.column("coordinates", .text).notNull()
            t.column("area", .double)
            t.column("perimeter", .double)
            t.column("fillColor", .text)
            t.column("strokeColor", .text)
            t.column("strokeWidth", .double).defaults(to: 2.0)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
            t.column("deletedAt", .datetime)
        }

        try db.create(index: "geometries_projectId", on: "geometries", columns: ["projectId"])
        try db.create(index: "geometries_recordId", on: "geometries", columns: ["recordId"])
        try db.create(index: "geometries_deletedAt", on: "geometries", columns: ["deletedAt"])

        try db.create(table: "geometry_vertices") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("geometryId", .integer)
                .notNull()
                .references("geometries", onDelete: .cascade)
            t.column("latitude", .double).notNull()
            t.column("longitude", .double).notNull()
            t.column("altitude", .double)
            t.column("sortOrder", .integer).notNull()
        }

        try db.create(
            index: "geometry_vertices_geometryId",
            on: "geometry_vertices",
            columns: ["geometryId"]
        )
        try db.create(
            index: "geometry_vertices_coordinates",
            on: "geometry_vertices",
            columns: ["latitude", "longitude"]
        )
    }
}
