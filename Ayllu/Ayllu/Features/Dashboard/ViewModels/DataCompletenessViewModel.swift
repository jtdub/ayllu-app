import Foundation
import GRDB

/// ViewModel for the data completeness dashboard
@Observable
final class DataCompletenessViewModel {
    private let dbPool: DatabasePool
    let projectId: Int64

    var completeness: ProjectCompleteness?
    var isLoading = false
    var error: String?
    var expandedTypeId: Int64?

    init(dbPool: DatabasePool, projectId: Int64) {
        self.dbPool = dbPool
        self.projectId = projectId
    }

    func load() {
        isLoading = true
        error = nil
        let service = DataCompletenessService(dbPool: dbPool)
        do {
            completeness = try service.computeCompleteness(projectId: projectId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func toggleExpanded(_ typeId: Int64?) {
        if expandedTypeId == typeId {
            expandedTypeId = nil
        } else {
            expandedTypeId = typeId
        }
    }
}
