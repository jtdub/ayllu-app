import XCTest
@testable import Ayllu

final class RecordRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepo: ProjectRepository!
    var typeRepo: RecordTypeRepository!
    var repository: RecordRepository!
    var testProjectId: Int64!
    var testTypeId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepo = ProjectRepository(dbPool: database.dbPool)
        typeRepo = RecordTypeRepository(dbPool: database.dbPool)
        repository = RecordRepository(dbPool: database.dbPool)

        let project = try projectRepo.create(Project(name: "Test Project"))
        testProjectId = project.id

        let recordType = try typeRepo.create(RecordType(
            projectId: testProjectId,
            name: "Site"
        ))
        testTypeId = recordType.id
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepo = nil
        typeRepo = nil
        repository = nil
        testProjectId = nil
        testTypeId = nil
    }

    // MARK: - Create

    func testCreateRecord() throws {
        let record = Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Site Alpha",
            description: "Primary excavation site",
            latitude: 37.7749,
            longitude: -122.4194
        )
        let created = try repository.create(record)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "Site Alpha")
        XCTAssertEqual(created.projectId, testProjectId)
        XCTAssertEqual(created.recordTypeId, testTypeId)
        XCTAssertNil(created.parentRecordId)
    }

    func testCreateRecordWithFormData() throws {
        let record = Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Site Beta",
            formData: ["soil_type": "clay", "depth": "2.5"]
        )
        let created = try repository.create(record)

        let fetched = try repository.fetchById(created.id!)
        XCTAssertEqual(fetched?.formData["soil_type"], "clay")
        XCTAssertEqual(fetched?.formData["depth"], "2.5")
    }

    func testCreateChildRecord() throws {
        let parent = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Parent Site"
        ))
        guard let parentId = parent.id else {
            XCTFail("Parent should have an ID")
            return
        }

        let child = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: parentId,
            name: "Child Trench"
        ))

        XCTAssertEqual(child.parentRecordId, parentId)
    }

    // MARK: - Read

    func testFetchAll() throws {
        try repository.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "A"))
        try repository.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "B"))

        let results = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(results.count, 2)
    }

    func testFetchAllWithSearch() throws {
        try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Alpha Site"
        ))
        try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Beta Site"
        ))

        let results = try repository.fetchAll(projectId: testProjectId, searchTerm: "Alpha")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Alpha Site")
    }

    func testFetchRoots() throws {
        let parent = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Root"
        ))
        guard let parentId = parent.id else {
            XCTFail("Parent should have an ID")
            return
        }

        try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: parentId,
            name: "Child"
        ))

        let roots = try repository.fetchRoots(projectId: testProjectId)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].name, "Root")
    }

    func testFetchChildren() throws {
        let parent = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Parent"
        ))
        guard let parentId = parent.id else {
            XCTFail("Parent should have an ID")
            return
        }

        try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: parentId,
            name: "Child 1"
        ))
        try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: parentId,
            name: "Child 2"
        ))

        let children = try repository.fetchChildren(parentRecordId: parentId)
        XCTAssertEqual(children.count, 2)
    }

    // MARK: - Ancestors (Breadcrumb)

    func testFetchAncestors() throws {
        let grandparent = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Site"
        ))
        let parent = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: grandparent.id,
            name: "Trench"
        ))
        let child = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: parent.id,
            name: "Context"
        ))
        guard let childId = child.id else {
            XCTFail("Child should have an ID")
            return
        }

        let ancestors = try repository.fetchAncestors(childId)
        XCTAssertEqual(ancestors.count, 3)
        XCTAssertEqual(ancestors[0].name, "Site")
        XCTAssertEqual(ancestors[1].name, "Trench")
        XCTAssertEqual(ancestors[2].name, "Context")
    }

    // MARK: - Update

    func testUpdate() throws {
        var record = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Original"
        ))
        record.name = "Updated"
        record.formData = ["key": "value"]

        let updated = try repository.update(record)
        XCTAssertEqual(updated.name, "Updated")

        let fetched = try repository.fetchById(updated.id!)
        XCTAssertEqual(fetched?.formData["key"], "value")
    }

    // MARK: - Delete

    func testSoftDelete() throws {
        let record = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Delete Me"
        ))
        guard let id = record.id else {
            XCTFail("Record should have an ID")
            return
        }

        try repository.delete(id: id)

        let results = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Count

    func testCountForProject() throws {
        try repository.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "A"))
        try repository.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "B"))

        let count = try repository.countForProject(testProjectId)
        XCTAssertEqual(count, 2)
    }

    func testCountChildren() throws {
        let parent = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Parent"
        ))
        guard let parentId = parent.id else {
            XCTFail("Parent should have an ID")
            return
        }

        try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: parentId,
            name: "Child 1"
        ))
        try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            parentRecordId: parentId,
            name: "Child 2"
        ))

        let count = try repository.countChildren(parentRecordId: parentId)
        XCTAssertEqual(count, 2)
    }

    func testCountByType() throws {
        let typeB = try typeRepo.create(RecordType(projectId: testProjectId, name: "Trench"))
        guard let typeBId = typeB.id else {
            XCTFail("Type should have an ID")
            return
        }

        try repository.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "S1"))
        try repository.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "S2"))
        try repository.create(Record(projectId: testProjectId, recordTypeId: typeBId, name: "T1"))

        let counts = try repository.countByType(projectId: testProjectId)
        XCTAssertEqual(counts[testTypeId], 2)
        XCTAssertEqual(counts[typeBId], 1)
    }
}
