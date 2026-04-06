import Foundation
import GRDB

/// Repository for RecordType CRUD operations
struct RecordTypeRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    @discardableResult
    func create(_ recordType: RecordType) throws -> RecordType {
        try dbPool.write { db in
            var newType = recordType
            try newType.insert(db)
            return newType
        }
    }

    // MARK: - Read

    /// Fetches all record types for a project, ordered by sortOrder
    func fetchAll(projectId: Int64) throws -> [RecordType] {
        try dbPool.read { db in
            try RecordType
                .filter(RecordType.Columns.projectId == projectId)
                .filter(RecordType.Columns.deletedAt == nil)
                .order(RecordType.Columns.sortOrder.asc)
                .fetchAll(db)
        }
    }

    /// Fetches root record types (no parent) for a project
    func fetchRoots(projectId: Int64) throws -> [RecordType] {
        try dbPool.read { db in
            try RecordType
                .filter(RecordType.Columns.projectId == projectId)
                .filter(RecordType.Columns.parentTypeId == nil)
                .filter(RecordType.Columns.deletedAt == nil)
                .order(RecordType.Columns.sortOrder.asc)
                .fetchAll(db)
        }
    }

    /// Fetches child record types of a given parent type
    func fetchChildren(parentTypeId: Int64) throws -> [RecordType] {
        try dbPool.read { db in
            try RecordType
                .filter(RecordType.Columns.parentTypeId == parentTypeId)
                .filter(RecordType.Columns.deletedAt == nil)
                .order(RecordType.Columns.sortOrder.asc)
                .fetchAll(db)
        }
    }

    /// Fetches a record type by ID
    func fetchById(_ id: Int64) throws -> RecordType? {
        try dbPool.read { db in
            try RecordType.fetchOne(db, key: id)
        }
    }

    // MARK: - Update

    @discardableResult
    func update(_ recordType: RecordType) throws -> RecordType {
        try dbPool.write { db in
            var updated = recordType
            updated.updatedAt = Date()
            try updated.update(db)
            return updated
        }
    }

    /// Reorders record types by updating their sortOrder
    func reorder(ids: [Int64]) throws {
        try dbPool.write { db in
            for (index, id) in ids.enumerated() {
                try db.execute(
                    sql: "UPDATE record_types SET sortOrder = ?, updatedAt = ? WHERE id = ?",
                    arguments: [index, Date(), id]
                )
            }
        }
    }

    // MARK: - Delete

    /// Soft deletes a record type
    func delete(id: Int64) throws {
        try dbPool.write { db in
            guard var recordType = try RecordType.fetchOne(db, key: id) else { return }
            recordType.deletedAt = Date()
            try recordType.update(db)
        }
    }

    /// Permanently deletes a record type
    func permanentlyDelete(id: Int64) throws {
        try dbPool.write { db in
            _ = try RecordType.deleteOne(db, key: id)
        }
    }

    // MARK: - Count

    func countForProject(_ projectId: Int64) throws -> Int {
        try dbPool.read { db in
            try RecordType
                .filter(RecordType.Columns.projectId == projectId)
                .filter(RecordType.Columns.deletedAt == nil)
                .fetchCount(db)
        }
    }
}
