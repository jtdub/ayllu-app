import Foundation

/// Overall completeness metrics for a project
struct ProjectCompleteness {
    let totalRecords: Int
    let completeCount: Int
    let draftCount: Int
    let incompleteCount: Int
    let typeCompleteness: [RecordTypeCompleteness]

    var completionPercentage: Double {
        guard totalRecords > 0 else { return 1.0 }
        return Double(completeCount) / Double(totalRecords)
    }
}

/// Completeness metrics for a single record type
struct RecordTypeCompleteness: Identifiable {
    let recordType: RecordType
    let totalCount: Int
    let completeCount: Int
    let draftCount: Int
    let incompleteRecords: [IncompleteRecord]

    var id: Int64? { recordType.id }

    var completionPercentage: Double {
        guard totalCount > 0 else { return 1.0 }
        return Double(completeCount) / Double(totalCount)
    }
}

/// A record that is missing required fields
struct IncompleteRecord: Identifiable {
    let record: Record
    let missingFields: [String]

    var id: Int64? { record.id }
}
