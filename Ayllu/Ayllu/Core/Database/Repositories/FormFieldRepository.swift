import Foundation
import GRDB

/// Repository for FormField CRUD operations
struct FormFieldRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    @discardableResult
    func create(_ field: FormField) throws -> FormField {
        try dbPool.write { db in
            var newField = field
            try newField.insert(db)
            return newField
        }
    }

    /// Creates multiple fields in a single transaction
    @discardableResult
    func batchCreate(_ fields: [FormField]) throws -> [FormField] {
        try dbPool.write { db in
            var created: [FormField] = []
            for var field in fields {
                try field.insert(db)
                created.append(field)
            }
            return created
        }
    }

    // MARK: - Read

    /// Fetches all fields for a form template, ordered by sortOrder
    func fetchAll(formTemplateId: Int64) throws -> [FormField] {
        try dbPool.read { db in
            try FormField
                .filter(FormField.Columns.formTemplateId == formTemplateId)
                .order(FormField.Columns.sortOrder.asc)
                .fetchAll(db)
        }
    }

    /// Fetches a field by ID
    func fetchById(_ id: Int64) throws -> FormField? {
        try dbPool.read { db in
            try FormField.fetchOne(db, key: id)
        }
    }

    // MARK: - Update

    @discardableResult
    func update(_ field: FormField) throws -> FormField {
        try dbPool.write { db in
            var updated = field
            updated.updatedAt = Date()
            try updated.update(db)
            return updated
        }
    }

    /// Reorders fields by updating their sortOrder
    func reorder(ids: [Int64]) throws {
        try dbPool.write { db in
            for (index, id) in ids.enumerated() {
                try db.execute(
                    sql: "UPDATE form_fields SET sortOrder = ?, updatedAt = ? WHERE id = ?",
                    arguments: [index, Date(), id]
                )
            }
        }
    }

    // MARK: - Delete

    func delete(id: Int64) throws {
        try dbPool.write { db in
            _ = try FormField.deleteOne(db, key: id)
        }
    }

    /// Deletes all fields for a form template
    func deleteAll(formTemplateId: Int64) throws {
        try dbPool.write { db in
            _ = try FormField
                .filter(FormField.Columns.formTemplateId == formTemplateId)
                .deleteAll(db)
        }
    }

    // MARK: - Count

    func countForTemplate(_ formTemplateId: Int64) throws -> Int {
        try dbPool.read { db in
            try FormField
                .filter(FormField.Columns.formTemplateId == formTemplateId)
                .fetchCount(db)
        }
    }
}
