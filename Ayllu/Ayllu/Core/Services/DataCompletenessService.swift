import Foundation
import GRDB

/// Computes data completeness metrics for a project
struct DataCompletenessService {
    let dbPool: DatabasePool

    func computeCompleteness(projectId: Int64) throws -> ProjectCompleteness {
        let typeRepo = RecordTypeRepository(dbPool: dbPool)
        let recordRepo = RecordRepository(dbPool: dbPool)
        let templateRepo = FormTemplateRepository(dbPool: dbPool)

        // Batch fetch: 1 query for types, 1 for all records (grouped in memory)
        let recordTypes = try typeRepo.fetchAll(projectId: projectId)
        let allRecords = try recordRepo.fetchAll(projectId: projectId)
        let recordsByType = Dictionary(grouping: allRecords, by: \.recordTypeId)

        // Pre-fetch required fields for all types
        var requiredFieldsByType: [Int64: [FormField]] = [:]
        for recordType in recordTypes {
            guard let typeId = recordType.id else { continue }
            if let result = try templateRepo.fetchWithFieldsByRecordType(typeId) {
                requiredFieldsByType[typeId] = result.1.filter(\.isRequired)
            }
        }

        var typeResults: [RecordTypeCompleteness] = []
        var totalRecords = 0
        var totalComplete = 0
        var totalDrafts = 0

        for recordType in recordTypes {
            guard let typeId = recordType.id else { continue }
            let records = recordsByType[typeId] ?? []
            let requiredFields = requiredFieldsByType[typeId] ?? []
            let typeComp = evaluateType(
                recordType: recordType,
                records: records,
                requiredFields: requiredFields
            )

            typeResults.append(typeComp)
            totalRecords += typeComp.totalCount
            totalComplete += typeComp.completeCount
            totalDrafts += typeComp.draftCount
        }

        return ProjectCompleteness(
            totalRecords: totalRecords,
            completeCount: totalComplete,
            draftCount: totalDrafts,
            incompleteCount: totalRecords - totalComplete - totalDrafts,
            typeCompleteness: typeResults
        )
    }

    private func evaluateType(
        recordType: RecordType,
        records: [Record],
        requiredFields: [FormField]
    ) -> RecordTypeCompleteness {
        var completeCount = 0
        var draftCount = 0
        var incompleteRecords: [IncompleteRecord] = []

        for record in records {
            if record.isDraft {
                draftCount += 1
                continue
            }

            let missing = requiredFields.filter { field in
                let value = record.formData[field.name] ?? ""
                return value.trimmingCharacters(in: .whitespaces).isEmpty
            }.map(\.label)

            if missing.isEmpty {
                completeCount += 1
            } else {
                incompleteRecords.append(IncompleteRecord(record: record, missingFields: missing))
            }
        }

        return RecordTypeCompleteness(
            recordType: recordType,
            totalCount: records.count,
            completeCount: completeCount,
            draftCount: draftCount,
            incompleteRecords: incompleteRecords
        )
    }
}
