import Foundation
import GRDB

/// ViewModel for managing record types within a project
@Observable
final class RecordTypeListViewModel {
    private let dbPool: DatabasePool
    let projectId: Int64

    var recordTypes: [RecordType] = []
    var isLoading = false
    var error: String?

    init(dbPool: DatabasePool, projectId: Int64) {
        self.dbPool = dbPool
        self.projectId = projectId
    }

    func loadRecordTypes() {
        isLoading = true
        error = nil
        let repo = RecordTypeRepository(dbPool: dbPool)
        do {
            recordTypes = try repo.fetchAll(projectId: projectId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createRecordType(
        name: String,
        description: String?,
        parentTypeId: Int64?,
        iconName: String?,
        color: String?
    ) {
        let repo = RecordTypeRepository(dbPool: dbPool)
        let sortOrder = recordTypes.count
        let recordType = RecordType(
            projectId: projectId,
            name: name,
            description: description,
            parentTypeId: parentTypeId,
            iconName: iconName,
            color: color,
            sortOrder: sortOrder
        )
        do {
            let created = try repo.create(recordType)

            // Auto-create a form template for this record type
            if let typeId = created.id {
                let templateRepo = FormTemplateRepository(dbPool: dbPool)
                let template = FormTemplate(recordTypeId: typeId, name: "\(name) Form")
                try templateRepo.create(template)
            }

            loadRecordTypes()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteRecordType(_ recordType: RecordType) {
        guard let id = recordType.id else { return }
        let repo = RecordTypeRepository(dbPool: dbPool)
        do {
            try repo.delete(id: id)
            loadRecordTypes()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func moveRecordTypes(from source: IndexSet, to destination: Int) {
        recordTypes.move(fromOffsets: source, toOffset: destination)
        let ids = recordTypes.compactMap(\.id)
        let repo = RecordTypeRepository(dbPool: dbPool)
        try? repo.reorder(ids: ids)
    }
}
