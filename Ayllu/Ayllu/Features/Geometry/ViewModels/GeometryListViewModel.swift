import Foundation
import GRDB

/// ViewModel for listing geometries within a project
@Observable
final class GeometryListViewModel {
    private let dbPool: DatabasePool
    let projectId: Int64

    var geometries: [Geometry] = []
    var isLoading = false
    var error: String?

    init(dbPool: DatabasePool, projectId: Int64) {
        self.dbPool = dbPool
        self.projectId = projectId
    }

    func loadGeometries() {
        isLoading = true
        error = nil
        let repo = GeometryRepository(dbPool: dbPool)
        do {
            geometries = try repo.fetchAll(projectId: projectId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteGeometry(_ geometry: Geometry) {
        guard let id = geometry.id else { return }
        let repo = GeometryRepository(dbPool: dbPool)
        do {
            try repo.delete(id: id)
            geometries.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
