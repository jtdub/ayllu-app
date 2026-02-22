import XCTest
@testable import Ayllu
import GRDB

final class ProjectListViewModelTests: XCTestCase {
    var database: DatabaseManager!
    var repository: ProjectRepository!
    var viewModel: ProjectListViewModel!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        repository = ProjectRepository(dbPool: database.dbPool)
        viewModel = ProjectListViewModel(repository: repository)
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
        viewModel = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertTrue(viewModel.projects.isEmpty)
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.showingCreateSheet)
        XCTAssertFalse(viewModel.showingDeleteConfirmation)
        XCTAssertNil(viewModel.projectToDelete)
    }

    func testIsEmptyWhenNoProjects() {
        XCTAssertTrue(viewModel.isEmpty)
    }

    // MARK: - Load Projects Tests

    func testLoadProjects() throws {
        // Create some projects directly in repository
        try repository.create(Project(name: "Project 1"))
        try repository.create(Project(name: "Project 2"))

        viewModel.loadProjects()

        XCTAssertEqual(viewModel.projects.count, 2)
        XCTAssertFalse(viewModel.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }

    func testLoadProjectsSetsLoadingState() throws {
        // Before loading
        XCTAssertFalse(viewModel.isLoading)

        // The loading state should be set and unset synchronously in this implementation
        viewModel.loadProjects()

        // After loading completes
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Create Project Tests

    func testCreateProject() {
        viewModel.createProject(
            name: "New Project",
            description: "Test description",
            startDate: nil,
            endDate: nil
        )

        XCTAssertEqual(viewModel.projects.count, 1)
        XCTAssertEqual(viewModel.projects.first?.name, "New Project")
        XCTAssertEqual(viewModel.projects.first?.description, "Test description")
    }

    func testCreateProjectInsertsAtTop() {
        viewModel.createProject(name: "First", description: nil, startDate: nil, endDate: nil)
        viewModel.createProject(name: "Second", description: nil, startDate: nil, endDate: nil)

        XCTAssertEqual(viewModel.projects.first?.name, "Second")
    }

    func testCreateProjectWithDates() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(86_400 * 7)

        viewModel.createProject(
            name: "Dated Project",
            description: nil,
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertNotNil(viewModel.projects.first?.startDate)
        XCTAssertNotNil(viewModel.projects.first?.endDate)
    }

    // MARK: - Delete Project Tests

    func testDeleteProject() {
        viewModel.createProject(name: "To Delete", description: nil, startDate: nil, endDate: nil)
        XCTAssertEqual(viewModel.projects.count, 1)

        if let project = viewModel.projects.first {
            viewModel.deleteProject(project)
        }

        XCTAssertTrue(viewModel.projects.isEmpty)
    }

    func testConfirmDeleteSetsState() {
        viewModel.createProject(name: "Test", description: nil, startDate: nil, endDate: nil)
        let project = viewModel.projects.first!

        viewModel.confirmDelete(project)

        XCTAssertTrue(viewModel.showingDeleteConfirmation)
        XCTAssertEqual(viewModel.projectToDelete?.id, project.id)
    }

    // MARK: - Search Tests

    func testFilteredProjectsWithEmptySearch() {
        viewModel.createProject(name: "Project A", description: nil, startDate: nil, endDate: nil)
        viewModel.createProject(name: "Project B", description: nil, startDate: nil, endDate: nil)

        viewModel.searchText = ""

        XCTAssertEqual(viewModel.filteredProjects.count, 2)
    }

    func testFilteredProjectsByName() {
        viewModel.createProject(name: "Alpha", description: nil, startDate: nil, endDate: nil)
        viewModel.createProject(name: "Beta", description: nil, startDate: nil, endDate: nil)
        viewModel.createProject(name: "Gamma", description: nil, startDate: nil, endDate: nil)

        viewModel.searchText = "beta"

        XCTAssertEqual(viewModel.filteredProjects.count, 1)
        XCTAssertEqual(viewModel.filteredProjects.first?.name, "Beta")
    }

    func testFilteredProjectsByDescription() {
        viewModel.createProject(
            name: "Project 1",
            description: "Archaeological survey",
            startDate: nil,
            endDate: nil
        )
        viewModel.createProject(
            name: "Project 2",
            description: "Wildlife monitoring",
            startDate: nil,
            endDate: nil
        )

        viewModel.searchText = "archaeological"

        XCTAssertEqual(viewModel.filteredProjects.count, 1)
        XCTAssertEqual(viewModel.filteredProjects.first?.name, "Project 1")
    }

    func testHasSearchResultsWhenMatching() {
        viewModel.createProject(name: "Test", description: nil, startDate: nil, endDate: nil)

        viewModel.searchText = "test"
        XCTAssertTrue(viewModel.hasSearchResults)

        viewModel.searchText = "xyz"
        XCTAssertFalse(viewModel.hasSearchResults)
    }

    // MARK: - Statistics Tests

    func testStatisticsForProject() throws {
        viewModel.createProject(name: "Stats Test", description: nil, startDate: nil, endDate: nil)
        guard let project = viewModel.projects.first, let projectId = project.id else {
            XCTFail("Project should exist")
            return
        }

        // Add some waypoints
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        try waypointRepo.create(Waypoint(projectId: projectId, name: "WP1", latitude: 0, longitude: 0))
        try waypointRepo.create(Waypoint(projectId: projectId, name: "WP2", latitude: 0, longitude: 0))

        let stats = viewModel.statistics(for: project)

        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.waypointCount, 2)
    }
}
