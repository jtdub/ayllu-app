import XCTest
@testable import Ayllu

final class RecordTypeRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepo: ProjectRepository!
    var repository: RecordTypeRepository!
    var testProjectId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepo = ProjectRepository(dbPool: database.dbPool)
        repository = RecordTypeRepository(dbPool: database.dbPool)

        let project = try projectRepo.create(Project(name: "Test Project"))
        testProjectId = project.id
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepo = nil
        repository = nil
        testProjectId = nil
    }

    // MARK: - Create

    func testCreateRecordType() throws {
        let recordType = RecordType(
            projectId: testProjectId,
            name: "Site",
            description: "Archaeological site",
            iconName: "building.columns",
            color: "#FF0000"
        )
        let created = try repository.create(recordType)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "Site")
        XCTAssertEqual(created.description, "Archaeological site")
        XCTAssertEqual(created.iconName, "building.columns")
        XCTAssertEqual(created.color, "#FF0000")
        XCTAssertEqual(created.projectId, testProjectId)
        XCTAssertNil(created.parentTypeId)
    }

    func testCreateChildRecordType() throws {
        let parent = try repository.create(RecordType(
            projectId: testProjectId,
            name: "Site"
        ))
        guard let parentId = parent.id else {
            XCTFail("Parent should have an ID")
            return
        }

        let child = try repository.create(RecordType(
            projectId: testProjectId,
            name: "Trench",
            parentTypeId: parentId
        ))

        XCTAssertEqual(child.parentTypeId, parentId)
    }

    // MARK: - Read

    func testFetchAll() throws {
        try repository.create(RecordType(projectId: testProjectId, name: "Site", sortOrder: 0))
        try repository.create(RecordType(projectId: testProjectId, name: "Trench", sortOrder: 1))
        try repository.create(RecordType(projectId: testProjectId, name: "Context", sortOrder: 2))

        let results = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].name, "Site")
        XCTAssertEqual(results[1].name, "Trench")
        XCTAssertEqual(results[2].name, "Context")
    }

    func testFetchRoots() throws {
        let site = try repository.create(RecordType(projectId: testProjectId, name: "Site"))
        guard let siteId = site.id else {
            XCTFail("Site should have an ID")
            return
        }

        try repository.create(RecordType(
            projectId: testProjectId,
            name: "Trench",
            parentTypeId: siteId
        ))

        let roots = try repository.fetchRoots(projectId: testProjectId)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].name, "Site")
    }

    func testFetchChildren() throws {
        let parent = try repository.create(RecordType(projectId: testProjectId, name: "Site"))
        guard let parentId = parent.id else {
            XCTFail("Parent should have an ID")
            return
        }

        try repository.create(RecordType(projectId: testProjectId, name: "Trench", parentTypeId: parentId))
        try repository.create(RecordType(projectId: testProjectId, name: "Unit", parentTypeId: parentId))

        let children = try repository.fetchChildren(parentTypeId: parentId)
        XCTAssertEqual(children.count, 2)
    }

    func testFetchById() throws {
        let created = try repository.create(RecordType(projectId: testProjectId, name: "Site"))
        guard let id = created.id else {
            XCTFail("RecordType should have an ID")
            return
        }

        let fetched = try repository.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Site")
    }

    // MARK: - Update

    func testUpdate() throws {
        var created = try repository.create(RecordType(projectId: testProjectId, name: "Site"))
        created.name = "Archaeological Site"
        created.iconName = "flag"

        let updated = try repository.update(created)
        XCTAssertEqual(updated.name, "Archaeological Site")
        XCTAssertEqual(updated.iconName, "flag")
    }

    func testReorder() throws {
        let first = try repository.create(RecordType(projectId: testProjectId, name: "A", sortOrder: 0))
        let second = try repository.create(RecordType(projectId: testProjectId, name: "B", sortOrder: 1))
        let third = try repository.create(RecordType(projectId: testProjectId, name: "C", sortOrder: 2))

        guard let firstId = first.id, let secondId = second.id, let thirdId = third.id else {
            XCTFail("RecordTypes should have IDs")
            return
        }

        // Reverse order
        try repository.reorder(ids: [thirdId, secondId, firstId])

        let reordered = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(reordered[0].name, "C")
        XCTAssertEqual(reordered[1].name, "B")
        XCTAssertEqual(reordered[2].name, "A")
    }

    // MARK: - Delete

    func testSoftDelete() throws {
        let created = try repository.create(RecordType(projectId: testProjectId, name: "Site"))
        guard let id = created.id else {
            XCTFail("RecordType should have an ID")
            return
        }

        try repository.delete(id: id)

        let results = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Count

    func testCountForProject() throws {
        try repository.create(RecordType(projectId: testProjectId, name: "Site"))
        try repository.create(RecordType(projectId: testProjectId, name: "Trench"))

        let count = try repository.countForProject(testProjectId)
        XCTAssertEqual(count, 2)
    }

    func testSoftDeletedNotCounted() throws {
        let created = try repository.create(RecordType(projectId: testProjectId, name: "Site"))
        guard let id = created.id else {
            XCTFail("RecordType should have an ID")
            return
        }

        try repository.delete(id: id)

        let count = try repository.countForProject(testProjectId)
        XCTAssertEqual(count, 0)
    }
}
