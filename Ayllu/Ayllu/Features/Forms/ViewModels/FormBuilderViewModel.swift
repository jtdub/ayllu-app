import Foundation
import GRDB

/// ViewModel for building form templates with field management
@Observable
final class FormBuilderViewModel {
    private let dbPool: DatabasePool
    let recordTypeId: Int64

    var template: FormTemplate?
    var fields: [FormField] = []
    var isLoading = false
    var error: String?

    init(dbPool: DatabasePool, recordTypeId: Int64) {
        self.dbPool = dbPool
        self.recordTypeId = recordTypeId
    }

    func loadTemplate() {
        isLoading = true
        error = nil
        let templateRepo = FormTemplateRepository(dbPool: dbPool)
        do {
            if let result = try templateRepo.fetchWithFieldsByRecordType(recordTypeId) {
                template = result.0
                fields = result.1
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func addField(_ field: FormField) {
        guard template?.id != nil else { return }
        let fieldRepo = FormFieldRepository(dbPool: dbPool)
        var newField = field
        newField.sortOrder = fields.count
        do {
            try fieldRepo.create(newField)
            loadTemplate()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateField(_ field: FormField) {
        let fieldRepo = FormFieldRepository(dbPool: dbPool)
        do {
            try fieldRepo.update(field)
            loadTemplate()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteField(_ field: FormField) {
        guard let id = field.id else { return }
        let fieldRepo = FormFieldRepository(dbPool: dbPool)
        do {
            try fieldRepo.delete(id: id)
            loadTemplate()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func moveFields(from source: IndexSet, to destination: Int) {
        fields.move(fromOffsets: source, toOffset: destination)
        let ids = fields.compactMap(\.id)
        let fieldRepo = FormFieldRepository(dbPool: dbPool)
        try? fieldRepo.reorder(ids: ids)
    }
}
