import XCTest
@testable import Ayllu

final class RecordDraftTests: XCTestCase {
    var database: DatabaseManager!
    var repository: RecordRepository!
    var testProjectId: Int64!
    var testTypeId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        let typeRepo = RecordTypeRepository(dbPool: database.dbPool)
        repository = RecordRepository(dbPool: database.dbPool)

        let project = try projectRepo.create(Project(name: "Test"))
        testProjectId = project.id
        let recordType = try typeRepo.create(RecordType(projectId: testProjectId, name: "Site"))
        testTypeId = recordType.id
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
    }

    func testCreateDraftRecord() throws {
        let record = try repository.create(Record(
            projectId: testProjectId,
            recordTypeId: testTypeId,
            name: "Draft Record",
            isDraft: true
        ))

        XCTAssertTrue(record.isDraft)
        let fetched = try repository.fetchById(record.id!)
        XCTAssertEqual(fetched?.isDraft, true)
    }

    func testFetchDrafts() throws {
        try repository.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Normal", isDraft: false
        ))
        try repository.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Draft 1", isDraft: true
        ))
        try repository.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Draft 2", isDraft: true
        ))

        let drafts = try repository.fetchDrafts(projectId: testProjectId)
        XCTAssertEqual(drafts.count, 2)
        XCTAssertTrue(drafts.allSatisfy(\.isDraft))
    }

    func testDraftRoundTrip() throws {
        var record = try repository.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Was Draft", isDraft: true
        ))
        XCTAssertTrue(record.isDraft)

        record.isDraft = false
        let updated = try repository.update(record)
        XCTAssertFalse(updated.isDraft)

        let fetched = try repository.fetchById(updated.id!)
        XCTAssertEqual(fetched?.isDraft, false)
    }

    func testDefaultIsNotDraft() throws {
        let record = try repository.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Normal"
        ))
        XCTAssertFalse(record.isDraft)
    }
}
