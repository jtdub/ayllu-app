import Foundation
import GRDB

/// ViewModel for navigating hierarchical records with breadcrumb support
@Observable
final class RecordHierarchyViewModel {
    private let dbPool: DatabasePool
    let projectId: Int64

    var currentRecords: [Record] = []
    var breadcrumbs: [Record] = []
    var currentParent: Record?
    var recordTypes: [Int64: RecordType] = [:]
    var childCounts: [Int64: Int] = [:]
    var isLoading = false
    var error: String?

    init(dbPool: DatabasePool, projectId: Int64) {
        self.dbPool = dbPool
        self.projectId = projectId
    }

    func loadInitial() {
        isLoading = true
        error = nil
        do {
            // Load all record types for display
            let typeRepo = RecordTypeRepository(dbPool: dbPool)
            let types = try typeRepo.fetchAll(projectId: projectId)
            recordTypes = Dictionary(uniqueKeysWithValues: types.compactMap { type in
                guard let id = type.id else { return nil }
                return (id, type)
            })

            // Load root records
            let recordRepo = RecordRepository(dbPool: dbPool)
            currentRecords = try recordRepo.fetchRoots(projectId: projectId)
            loadChildCounts()
            breadcrumbs = []
            currentParent = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func navigateToRecord(_ record: Record) {
        guard let recordId = record.id else { return }
        let recordRepo = RecordRepository(dbPool: dbPool)
        do {
            currentRecords = try recordRepo.fetchChildren(parentRecordId: recordId)
            loadChildCounts()
            breadcrumbs.append(record)
            currentParent = record
        } catch {
            self.error = error.localizedDescription
        }
    }

    func navigateToBreadcrumb(at index: Int) {
        if index < 0 {
            loadInitial()
            return
        }

        guard index < breadcrumbs.count else { return }
        let record = breadcrumbs[index]
        guard let recordId = record.id else { return }

        let recordRepo = RecordRepository(dbPool: dbPool)
        do {
            currentRecords = try recordRepo.fetchChildren(parentRecordId: recordId)
            loadChildCounts()
            breadcrumbs = Array(breadcrumbs.prefix(index + 1))
            currentParent = record
        } catch {
            self.error = error.localizedDescription
        }
    }

    func navigateUp() {
        if breadcrumbs.isEmpty {
            return
        }
        breadcrumbs.removeLast()
        if let parent = breadcrumbs.last {
            guard let parentId = parent.id else { return }
            let recordRepo = RecordRepository(dbPool: dbPool)
            do {
                currentRecords = try recordRepo.fetchChildren(parentRecordId: parentId)
                loadChildCounts()
                currentParent = parent
            } catch {
                self.error = error.localizedDescription
            }
        } else {
            loadInitial()
        }
    }

    func deleteRecord(_ record: Record) {
        guard let id = record.id else { return }
        let recordRepo = RecordRepository(dbPool: dbPool)
        do {
            try recordRepo.delete(id: id)
            currentRecords.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func recordTypeName(for record: Record) -> String {
        recordTypes[record.recordTypeId]?.name ?? "Unknown"
    }

    func recordTypeIcon(for record: Record) -> String {
        recordTypes[record.recordTypeId]?.iconName ?? "doc"
    }

    func childCount(for record: Record) -> Int {
        guard let id = record.id else { return 0 }
        return childCounts[id] ?? 0
    }

    private func loadChildCounts() {
        let ids = currentRecords.compactMap(\.id)
        let repo = RecordRepository(dbPool: dbPool)
        childCounts = (try? repo.batchChildCounts(parentIds: ids)) ?? [:]
    }
}
