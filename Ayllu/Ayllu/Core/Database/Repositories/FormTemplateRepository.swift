import Foundation
import GRDB

/// Repository for FormTemplate CRUD operations
struct FormTemplateRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    @discardableResult
    func create(_ template: FormTemplate) throws -> FormTemplate {
        try dbPool.write { db in
            var newTemplate = template
            try newTemplate.insert(db)
            return newTemplate
        }
    }

    // MARK: - Read

    /// Fetches a form template by its associated record type
    func fetchByRecordType(_ recordTypeId: Int64) throws -> FormTemplate? {
        try dbPool.read { db in
            try FormTemplate
                .filter(FormTemplate.Columns.recordTypeId == recordTypeId)
                .fetchOne(db)
        }
    }

    /// Fetches a form template by ID
    func fetchById(_ id: Int64) throws -> FormTemplate? {
        try dbPool.read { db in
            try FormTemplate.fetchOne(db, key: id)
        }
    }

    /// Fetches a form template with all its fields, ordered by sortOrder
    func fetchWithFields(_ templateId: Int64) throws -> (FormTemplate, [FormField])? {
        try dbPool.read { db in
            guard let template = try FormTemplate.fetchOne(db, key: templateId) else {
                return nil
            }
            let fields = try FormField
                .filter(FormField.Columns.formTemplateId == templateId)
                .order(FormField.Columns.sortOrder.asc)
                .fetchAll(db)
            return (template, fields)
        }
    }

    /// Fetches a form template with fields by record type
    func fetchWithFieldsByRecordType(_ recordTypeId: Int64) throws -> (FormTemplate, [FormField])? {
        try dbPool.read { db in
            guard let template = try FormTemplate
                .filter(FormTemplate.Columns.recordTypeId == recordTypeId)
                .fetchOne(db) else {
                return nil
            }
            guard let templateId = template.id else { return nil }
            let fields = try FormField
                .filter(FormField.Columns.formTemplateId == templateId)
                .order(FormField.Columns.sortOrder.asc)
                .fetchAll(db)
            return (template, fields)
        }
    }

    // MARK: - Update

    @discardableResult
    func update(_ template: FormTemplate) throws -> FormTemplate {
        try dbPool.write { db in
            var updated = template
            updated.updatedAt = Date()
            try updated.update(db)
            return updated
        }
    }

    /// Increments the template version
    @discardableResult
    func incrementVersion(_ templateId: Int64) throws -> FormTemplate? {
        try dbPool.write { db in
            guard var template = try FormTemplate.fetchOne(db, key: templateId) else {
                return nil
            }
            template.version += 1
            template.updatedAt = Date()
            try template.update(db)
            return template
        }
    }

    // MARK: - Delete

    func delete(id: Int64) throws {
        try dbPool.write { db in
            _ = try FormTemplate.deleteOne(db, key: id)
        }
    }
}
