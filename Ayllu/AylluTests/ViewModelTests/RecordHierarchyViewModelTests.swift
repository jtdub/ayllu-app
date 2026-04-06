import XCTest
@testable import Ayllu

final class RecordHierarchyViewModelTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepo: ProjectRepository!
    var typeRepo: RecordTypeRepository!
    var recordRepo: RecordRepository!
    var viewModel: RecordHierarchyViewModel!
    var testProjectId: Int64!
    var testTypeId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepo = ProjectRepository(dbPool: database.dbPool)
        typeRepo = RecordTypeRepository(dbPool: database.dbPool)
        recordRepo = RecordRepository(dbPool: database.dbPool)

        let project = try projectRepo.create(Project(name: "Test Project"))
        testProjectId = project.id

        let recordType = try typeRepo.create(RecordType(projectId: testProjectId, name: "Site"))
        testTypeId = recordType.id

        viewModel = RecordHierarchyViewModel(dbPool: database.dbPool, projectId: testProjectId)
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepo = nil
        typeRepo = nil
        recordRepo = nil
        viewModel = nil
    }

    // MARK: - Initial State

    func testInitialStateEmpty() {
        viewModel.loadInitial()
        XCTAssertTrue(viewModel.currentRecords.isEmpty)
        XCTAssertTrue(viewModel.breadcrumbs.isEmpty)
        XCTAssertNil(viewModel.currentParent)
    }

    func testLoadInitialShowsRootRecords() throws {
        try recordRepo.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "Site A"))
        try recordRepo.create(Record(projectId: testProjectId, recordTypeId: testTypeId, name: "Site B"))

        viewModel.loadInitial()
        XCTAssertEqual(viewModel.currentRecords.count, 2)
        XCTAssertTrue(viewModel.breadcrumbs.isEmpty)
    }

    // MARK: - Navigation

    func testNavigateToRecord() throws {
        let parent = try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Parent"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: parent.id, name: "Child 1"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: parent.id, name: "Child 2"
        ))

        viewModel.loadInitial()
        XCTAssertEqual(viewModel.currentRecords.count, 1)

        viewModel.navigateToRecord(viewModel.currentRecords[0])
        XCTAssertEqual(viewModel.currentRecords.count, 2)
        XCTAssertEqual(viewModel.breadcrumbs.count, 1)
        XCTAssertEqual(viewModel.breadcrumbs[0].name, "Parent")
        XCTAssertEqual(viewModel.currentParent?.name, "Parent")
    }

    func testNavigateUp() throws {
        let parent = try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Parent"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: parent.id, name: "Child"
        ))

        viewModel.loadInitial()
        viewModel.navigateToRecord(viewModel.currentRecords[0])
        XCTAssertEqual(viewModel.breadcrumbs.count, 1)

        viewModel.navigateUp()
        XCTAssertTrue(viewModel.breadcrumbs.isEmpty)
        XCTAssertNil(viewModel.currentParent)
        XCTAssertEqual(viewModel.currentRecords.count, 1)
    }

    func testNavigateToBreadcrumb() throws {
        let site = try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Site"
        ))
        let trench = try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: site.id, name: "Trench"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: trench.id, name: "Context"
        ))

        viewModel.loadInitial()
        viewModel.navigateToRecord(viewModel.currentRecords[0])
        viewModel.navigateToRecord(viewModel.currentRecords[0])
        XCTAssertEqual(viewModel.breadcrumbs.count, 2)

        viewModel.navigateToBreadcrumb(at: 0)
        XCTAssertEqual(viewModel.breadcrumbs.count, 1)
        XCTAssertEqual(viewModel.currentParent?.name, "Site")
    }

    func testNavigateToBreadcrumbRoot() throws {
        let site = try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Site"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: site.id, name: "Trench"
        ))

        viewModel.loadInitial()
        viewModel.navigateToRecord(viewModel.currentRecords[0])
        XCTAssertEqual(viewModel.breadcrumbs.count, 1)

        viewModel.navigateToBreadcrumb(at: -1)
        XCTAssertTrue(viewModel.breadcrumbs.isEmpty)
    }

    // MARK: - Child Counts

    func testChildCountBatchLoaded() throws {
        let parent = try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Parent"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: parent.id, name: "Child 1"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            parentRecordId: parent.id, name: "Child 2"
        ))

        viewModel.loadInitial()
        XCTAssertEqual(viewModel.childCount(for: viewModel.currentRecords[0]), 2)
    }

    func testChildCountZeroForLeaf() throws {
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Leaf"
        ))

        viewModel.loadInitial()
        XCTAssertEqual(viewModel.childCount(for: viewModel.currentRecords[0]), 0)
    }

    // MARK: - Delete

    func testDeleteRecord() throws {
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Delete Me"
        ))

        viewModel.loadInitial()
        XCTAssertEqual(viewModel.currentRecords.count, 1)

        viewModel.deleteRecord(viewModel.currentRecords[0])
        XCTAssertTrue(viewModel.currentRecords.isEmpty)
    }

    // MARK: - Record Type Display

    func testRecordTypeName() throws {
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId, name: "Test"
        ))

        viewModel.loadInitial()
        XCTAssertEqual(viewModel.recordTypeName(for: viewModel.currentRecords[0]), "Site")
    }
}
