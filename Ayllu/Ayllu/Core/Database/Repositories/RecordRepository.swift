import Foundation
import GRDB

/// Repository for Record CRUD operations with hierarchy support
struct RecordRepository {
    let dbPool: DatabasePool

    // MARK: - Create

    @discardableResult
    func create(_ record: Record) throws -> Record {
        try dbPool.write { db in
            var newRecord = record
            try newRecord.insert(db)
            return newRecord
        }
    }

    // MARK: - Read

    /// Fetches all records for a project, optionally filtered by record type
    func fetchAll(
        projectId: Int64,
        recordTypeId: Int64? = nil,
        searchTerm: String? = nil
    ) throws -> [Record] {
        try dbPool.read { db in
            var query = Record
                .filter(Record.Columns.projectId == projectId)
                .filter(Record.Columns.deletedAt == nil)
                .order(Record.Columns.createdAt.desc)

            if let recordTypeId {
                query = query.filter(Record.Columns.recordTypeId == recordTypeId)
            }

            if let search = searchTerm, !search.isEmpty {
                let pattern = "%\(search)%"
                query = query.filter(
                    Record.Columns.name.like(pattern) ||
                    Record.Columns.description.like(pattern) ||
                    Record.Columns.formData.like(pattern)
                )
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches root records (no parent) for a project
    func fetchRoots(projectId: Int64) throws -> [Record] {
        try dbPool.read { db in
            try Record
                .filter(Record.Columns.projectId == projectId)
                .filter(Record.Columns.parentRecordId == nil)
                .filter(Record.Columns.deletedAt == nil)
                .order(Record.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetches child records of a given parent
    func fetchChildren(parentRecordId: Int64) throws -> [Record] {
        try dbPool.read { db in
            try Record
                .filter(Record.Columns.parentRecordId == parentRecordId)
                .filter(Record.Columns.deletedAt == nil)
                .order(Record.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetches a record by ID
    func fetchById(_ id: Int64) throws -> Record? {
        try dbPool.read { db in
            try Record.fetchOne(db, key: id)
        }
    }

    /// Walks up the hierarchy to build a breadcrumb path from root to the given record
    func fetchAncestors(_ recordId: Int64) throws -> [Record] {
        try dbPool.read { db in
            var ancestors: [Record] = []
            var currentId: Int64? = recordId
            var visited: Set<Int64> = []

            while let id = currentId {
                guard !visited.contains(id) else { break }
                visited.insert(id)
                guard let record = try Record.fetchOne(db, key: id) else { break }
                ancestors.insert(record, at: 0)
                currentId = record.parentRecordId
            }

            return ancestors
        }
    }

    // MARK: - Update

    @discardableResult
    func update(_ record: Record) throws -> Record {
        try dbPool.write { db in
            var updated = record
            updated.updatedAt = Date()
            try updated.update(db)
            return updated
        }
    }

    // MARK: - Delete

    /// Soft deletes a record (children cascade via FK)
    func delete(id: Int64) throws {
        try dbPool.write { db in
            guard var record = try Record.fetchOne(db, key: id) else { return }
            record.deletedAt = Date()
            try record.update(db)
        }
    }

    /// Permanently deletes a record (children cascade via FK)
    func permanentlyDelete(id: Int64) throws {
        try dbPool.write { db in
            _ = try Record.deleteOne(db, key: id)
        }
    }

    // MARK: - Count

    func countForProject(_ projectId: Int64) throws -> Int {
        try dbPool.read { db in
            try Record
                .filter(Record.Columns.projectId == projectId)
                .filter(Record.Columns.deletedAt == nil)
                .fetchCount(db)
        }
    }

    func countChildren(parentRecordId: Int64) throws -> Int {
        try dbPool.read { db in
            try Record
                .filter(Record.Columns.parentRecordId == parentRecordId)
                .filter(Record.Columns.deletedAt == nil)
                .fetchCount(db)
        }
    }

    /// Batch-fetches child counts for multiple parent record IDs in a single query
    func batchChildCounts(parentIds: [Int64]) throws -> [Int64: Int] {
        guard !parentIds.isEmpty else { return [:] }
        return try dbPool.read { db in
            let placeholders = parentIds.map { _ in "?" }.joined(separator: ",")
            let sql = """
                SELECT parentRecordId, COUNT(*) as count
                FROM records
                WHERE parentRecordId IN (\(placeholders)) AND deletedAt IS NULL
                GROUP BY parentRecordId
                """
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(parentIds))

            var result: [Int64: Int] = [:]
            for row in rows {
                let parentId: Int64 = row["parentRecordId"]
                let count: Int = row["count"]
                result[parentId] = count
            }
            return result
        }
    }

    /// Returns counts grouped by record type for a project
    func countByType(projectId: Int64) throws -> [Int64: Int] {
        try dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT recordTypeId, COUNT(*) as count
                FROM records
                WHERE projectId = ? AND deletedAt IS NULL
                GROUP BY recordTypeId
                """, arguments: [projectId])

            var result: [Int64: Int] = [:]
            for row in rows {
                let typeId: Int64 = row["recordTypeId"]
                let count: Int = row["count"]
                result[typeId] = count
            }
            return result
        }
    }
}
