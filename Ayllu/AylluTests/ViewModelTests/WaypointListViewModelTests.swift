import XCTest
@testable import Ayllu
import GRDB
import CoreLocation

final class WaypointListViewModelTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepository: ProjectRepository!
    var waypointRepository: WaypointRepository!
    var projectId: Int64!
    var viewModel: WaypointListViewModel!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepository = ProjectRepository(dbPool: database.dbPool)
        waypointRepository = WaypointRepository(dbPool: database.dbPool)

        // Create a project for waypoints
        let project = try projectRepository.create(Project(name: "Test Project"))
        projectId = project.id

        viewModel = WaypointListViewModel(repository: waypointRepository, projectId: projectId)
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepository = nil
        waypointRepository = nil
        projectId = nil
        viewModel = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertTrue(viewModel.waypoints.isEmpty)
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertNil(viewModel.selectedCategory)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.showingCreateSheet)
        XCTAssertFalse(viewModel.showingDeleteConfirmation)
        XCTAssertNil(viewModel.waypointToDelete)
    }

    func testIsEmptyWhenNoWaypoints() {
        XCTAssertTrue(viewModel.isEmpty)
    }

    func testProjectIdIsSet() {
        XCTAssertEqual(viewModel.projectId, projectId)
    }

    // MARK: - Load Waypoints Tests

    func testLoadWaypoints() throws {
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "WP1",
            latitude: 37.0,
            longitude: -122.0
        ))
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "WP2",
            latitude: 38.0,
            longitude: -123.0
        ))

        viewModel.loadWaypoints()

        XCTAssertEqual(viewModel.waypoints.count, 2)
        XCTAssertFalse(viewModel.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }

    func testLoadWaypointsOnlyLoadsForProject() throws {
        // Create another project
        let otherProject = try projectRepository.create(Project(name: "Other"))
        guard let otherProjectId = otherProject.id else {
            XCTFail("Project should have ID")
            return
        }

        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "My WP",
            latitude: 0,
            longitude: 0
        ))
        try waypointRepository.create(Waypoint(
            projectId: otherProjectId,
            name: "Other WP",
            latitude: 0,
            longitude: 0
        ))

        viewModel.loadWaypoints()

        XCTAssertEqual(viewModel.waypoints.count, 1)
        XCTAssertEqual(viewModel.waypoints.first?.name, "My WP")
    }

    // MARK: - Create Quick Waypoint Tests

    func testCreateQuickWaypoint() {
        let location = CLLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )

        viewModel.createQuickWaypoint(location: location)

        XCTAssertEqual(viewModel.waypoints.count, 1)
        XCTAssertEqual(viewModel.waypoints.first?.latitude ?? 0, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(viewModel.waypoints.first?.longitude ?? 0, -122.4194, accuracy: 0.0001)
    }

    func testCreateQuickWaypointWithCategory() {
        let location = CLLocation(latitude: 37.0, longitude: -122.0)

        viewModel.createQuickWaypoint(location: location, category: .artifact)

        XCTAssertEqual(viewModel.waypoints.first?.category, .artifact)
    }

    func testCreateQuickWaypointInsertsAtTop() {
        let location1 = CLLocation(latitude: 37.0, longitude: -122.0)
        let location2 = CLLocation(latitude: 38.0, longitude: -123.0)

        viewModel.createQuickWaypoint(location: location1)
        viewModel.createQuickWaypoint(location: location2)

        XCTAssertEqual(viewModel.waypoints.first?.latitude ?? 0, 38.0, accuracy: 0.1)
    }

    // MARK: - Delete Waypoint Tests

    func testDeleteWaypoint() throws {
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "To Delete",
            latitude: 0,
            longitude: 0
        ))
        viewModel.loadWaypoints()
        XCTAssertEqual(viewModel.waypoints.count, 1)

        if let waypoint = viewModel.waypoints.first {
            viewModel.deleteWaypoint(waypoint)
        }

        XCTAssertTrue(viewModel.waypoints.isEmpty)
    }

    func testConfirmDeleteSetsState() throws {
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "Test",
            latitude: 0,
            longitude: 0
        ))
        viewModel.loadWaypoints()
        let waypoint = viewModel.waypoints.first!

        viewModel.confirmDelete(waypoint)

        XCTAssertTrue(viewModel.showingDeleteConfirmation)
        XCTAssertEqual(viewModel.waypointToDelete?.id, waypoint.id)
    }

    // MARK: - Filter Tests

    func testFilteredWaypointsWithEmptySearch() throws {
        try waypointRepository.create(Waypoint(projectId: projectId, name: "WP1", latitude: 0, longitude: 0))
        try waypointRepository.create(Waypoint(projectId: projectId, name: "WP2", latitude: 0, longitude: 0))
        viewModel.loadWaypoints()

        viewModel.searchText = ""

        XCTAssertEqual(viewModel.filteredWaypoints.count, 2)
    }

    func testFilteredWaypointsByName() throws {
        try waypointRepository.create(Waypoint(projectId: projectId, name: "Site Alpha", latitude: 0, longitude: 0))
        try waypointRepository.create(Waypoint(projectId: projectId, name: "Site Beta", latitude: 0, longitude: 0))
        try waypointRepository.create(Waypoint(projectId: projectId, name: "Feature Gamma", latitude: 0, longitude: 0))
        viewModel.loadWaypoints()

        viewModel.searchText = "site"

        XCTAssertEqual(viewModel.filteredWaypoints.count, 2)
    }

    func testFilteredWaypointsByDescription() throws {
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "WP1",
            description: "Ancient pottery found here",
            latitude: 0,
            longitude: 0
        ))
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "WP2",
            description: "Modern artifact",
            latitude: 0,
            longitude: 0
        ))
        viewModel.loadWaypoints()

        viewModel.searchText = "pottery"

        XCTAssertEqual(viewModel.filteredWaypoints.count, 1)
        XCTAssertEqual(viewModel.filteredWaypoints.first?.name, "WP1")
    }

    func testFilteredWaypointsByCategory() throws {
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "Artifact 1",
            latitude: 0,
            longitude: 0,
            category: .artifact
        ))
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "Site 1",
            latitude: 0,
            longitude: 0,
            category: .site
        ))
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "Artifact 2",
            latitude: 0,
            longitude: 0,
            category: .artifact
        ))
        viewModel.loadWaypoints()

        viewModel.selectedCategory = .artifact

        XCTAssertEqual(viewModel.filteredWaypoints.count, 2)
        XCTAssertTrue(viewModel.filteredWaypoints.allSatisfy { $0.category == .artifact })
    }

    func testFilteredWaypointsCombinesSearchAndCategory() throws {
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "Pottery A",
            latitude: 0,
            longitude: 0,
            category: .artifact
        ))
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "Stone B",
            latitude: 0,
            longitude: 0,
            category: .artifact
        ))
        try waypointRepository.create(Waypoint(
            projectId: projectId,
            name: "Pottery Site",
            latitude: 0,
            longitude: 0,
            category: .site
        ))
        viewModel.loadWaypoints()

        viewModel.selectedCategory = .artifact
        viewModel.searchText = "pottery"

        XCTAssertEqual(viewModel.filteredWaypoints.count, 1)
        XCTAssertEqual(viewModel.filteredWaypoints.first?.name, "Pottery A")
    }

    func testHasSearchResultsWhenMatching() throws {
        try waypointRepository.create(Waypoint(projectId: projectId, name: "Test", latitude: 0, longitude: 0))
        viewModel.loadWaypoints()

        viewModel.searchText = "test"
        XCTAssertTrue(viewModel.hasSearchResults)

        viewModel.searchText = "xyz"
        XCTAssertFalse(viewModel.hasSearchResults)
    }

    // MARK: - ViewModel Without Project Tests

    func testViewModelWithoutProjectIdDoesNotCreateQuickWaypoint() {
        let viewModelNoProject = WaypointListViewModel(repository: waypointRepository, projectId: nil)
        let location = CLLocation(latitude: 37.0, longitude: -122.0)

        viewModelNoProject.createQuickWaypoint(location: location)

        XCTAssertTrue(viewModelNoProject.waypoints.isEmpty)
    }
}
