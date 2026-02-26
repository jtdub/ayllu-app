import XCTest
@testable import Ayllu
import GRDB

final class ProjectRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var repository: ProjectRepository!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        repository = ProjectRepository(dbPool: database.dbPool)
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
    }

    // MARK: - Create Tests

    func testCreateProject() throws {
        let project = Project(name: "Test Project", description: "A test project")
        let created = try repository.create(project)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "Test Project")
        XCTAssertEqual(created.description, "A test project")
        XCTAssertNotNil(created.createdAt)
        XCTAssertNotNil(created.updatedAt)
    }

    func testCreateProjectWithDates() throws {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(86_400 * 7)  // 7 days later

        let project = Project(
            name: "Field Survey",
            description: "Summer survey",
            startDate: startDate,
            endDate: endDate
        )
        let created = try repository.create(project)

        XCTAssertNotNil(created.startDate)
        XCTAssertNotNil(created.endDate)
    }

    // MARK: - Read Tests

    func testFetchAll() throws {
        try repository.create(Project(name: "Project 1"))
        try repository.create(Project(name: "Project 2"))
        try repository.create(Project(name: "Project 3"))

        let projects = try repository.fetchAll()
        XCTAssertEqual(projects.count, 3)
    }

    func testFetchAllWithSearch() throws {
        try repository.create(Project(name: "Archaeological Survey"))
        try repository.create(Project(name: "Biological Monitoring"))
        try repository.create(Project(name: "Cultural Resource Management"))

        let results = try repository.fetchAll(searchTerm: "survey")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Archaeological Survey")
    }

    func testFetchById() throws {
        let created = try repository.create(Project(name: "Test"))
        guard let id = created.id else {
            XCTFail("Project should have an ID")
            return
        }

        let fetched = try repository.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Test")
    }

    func testFetchByIdNotFound() throws {
        let fetched = try repository.fetchById(99_999)
        XCTAssertNil(fetched)
    }

    // MARK: - Update Tests

    func testUpdateProject() throws {
        var project = try repository.create(Project(name: "Original Name"))
        project.name = "Updated Name"
        project.description = "Added description"

        let updated = try repository.update(project)
        XCTAssertEqual(updated.name, "Updated Name")
        XCTAssertEqual(updated.description, "Added description")
    }

    // MARK: - Delete Tests

    func testDeleteProject() throws {
        let project = try repository.create(Project(name: "To Delete"))
        guard let id = project.id else {
            XCTFail("Project should have an ID")
            return
        }

        // Soft delete
        try repository.delete(id: id)

        // Should still exist in database but marked as deleted
        let fetched = try repository.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertNotNil(fetched?.deletedAt)

        // Should not appear in fetchAll (which excludes deleted)
        let allProjects = try repository.fetchAll()
        XCTAssertFalse(allProjects.contains(where: { $0.id == id }))

        // Should appear when includeDeleted is true
        let allIncludingDeleted = try repository.fetchAll(includeDeleted: true)
        XCTAssertTrue(allIncludingDeleted.contains(where: { $0.id == id }))
    }

    // MARK: - Statistics Tests

    func testStatistics() throws {
        let project = try repository.create(Project(name: "Stats Test"))
        guard let projectId = project.id else {
            XCTFail("Project should have an ID")
            return
        }

        // Create some waypoints
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        try waypointRepo.create(Waypoint(
            projectId: projectId,
            name: "WP1",
            latitude: 0,
            longitude: 0
        ))
        try waypointRepo.create(Waypoint(
            projectId: projectId,
            name: "WP2",
            latitude: 0,
            longitude: 0
        ))

        // Create some notes
        let noteRepo = NoteRepository(dbPool: database.dbPool)
        try noteRepo.create(FieldNote(
            projectId: projectId,
            title: "Note 1"
        ))

        let stats = try repository.statistics(for: projectId)
        XCTAssertEqual(stats.waypointCount, 2)
        XCTAssertEqual(stats.noteCount, 1)
        XCTAssertEqual(stats.photoCount, 0)
        XCTAssertEqual(stats.trackCount, 0)
    }

    // MARK: - Count Tests

    func testCount() throws {
        XCTAssertEqual(try repository.count(), 0)

        try repository.create(Project(name: "P1"))
        try repository.create(Project(name: "P2"))

        XCTAssertEqual(try repository.count(), 2)
    }
}
