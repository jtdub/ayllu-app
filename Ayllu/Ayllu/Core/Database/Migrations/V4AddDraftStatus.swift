import Foundation
import GRDB

/// V4 Migration: Add draft status to records
enum V4AddDraftStatus {
    static func migrate(_ db: Database) throws {
        try db.alter(table: "records") { t in
            t.add(column: "isDraft", .boolean).notNull().defaults(to: false)
        }
    }
}
