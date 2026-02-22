import Foundation
import CoreLocation

/// ViewModel for the waypoint list
@Observable
final class WaypointListViewModel {
    // MARK: - State

    var waypoints: [Waypoint] = []
    var searchText: String = ""
    var selectedCategory: WaypointCategory?
    var isLoading: Bool = false
    var error: Error?
    var showingCreateSheet: Bool = false
    var showingDeleteConfirmation: Bool = false
    var waypointToDelete: Waypoint?

    // MARK: - Dependencies

    private let repository: WaypointRepository
    let projectId: Int64?

    // MARK: - Computed Properties

    var filteredWaypoints: [Waypoint] {
        var result = waypoints

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { waypoint in
                waypoint.name.localizedCaseInsensitiveContains(searchText) ||
                (waypoint.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                waypoint.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }

    var isEmpty: Bool {
        waypoints.isEmpty
    }

    var hasSearchResults: Bool {
        !filteredWaypoints.isEmpty
    }

    // MARK: - Initialization

    init(repository: WaypointRepository, projectId: Int64? = nil) {
        self.repository = repository
        self.projectId = projectId
    }

    // MARK: - Actions

    func loadWaypoints() {
        isLoading = true
        error = nil

        do {
            waypoints = try repository.fetchAll(projectId: projectId)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func createQuickWaypoint(location: CLLocation, category: WaypointCategory? = nil) {
        guard let projectId = projectId else { return }

        do {
            let newWaypoint = try repository.createQuick(
                projectId: projectId,
                location: location,
                category: category
            )
            waypoints.insert(newWaypoint, at: 0)
        } catch {
            self.error = error
        }
    }

    func deleteWaypoint(_ waypoint: Waypoint) {
        guard let id = waypoint.id else { return }

        do {
            try repository.delete(id: id)
            withAnimation {
                waypoints.removeAll { $0.id == id }
            }
        } catch {
            self.error = error
        }
    }

    func confirmDelete(_ waypoint: Waypoint) {
        waypointToDelete = waypoint
        showingDeleteConfirmation = true
    }
}
