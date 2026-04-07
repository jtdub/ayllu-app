import XCTest
@testable import Ayllu

final class DataCompletenessServiceTests: XCTestCase {
    var database: DatabaseManager!
    var service: DataCompletenessService!
    var testProjectId: Int64!
    var testTypeId: Int64!
    var testTemplateId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        service = DataCompletenessService(dbPool: database.dbPool)

        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        let project = try projectRepo.create(Project(name: "Test"))
        testProjectId = project.id

        let typeRepo = RecordTypeRepository(dbPool: database.dbPool)
        let recordType = try typeRepo.create(RecordType(projectId: testProjectId, name: "Site"))
        testTypeId = recordType.id

        let templateRepo = FormTemplateRepository(dbPool: database.dbPool)
        let template = try templateRepo.create(FormTemplate(recordTypeId: testTypeId, name: "Site Form"))
        testTemplateId = template.id
    }

    override func tearDownWithError() throws {
        database = nil
        service = nil
    }

    func testEmptyProjectIs100Percent() throws {
        let result = try service.computeCompleteness(projectId: testProjectId)

        XCTAssertEqual(result.totalRecords, 0)
        XCTAssertEqual(result.completionPercentage, 1.0, accuracy: 0.01)
    }

    func testAllRecordsComplete() throws {
        let fieldRepo = FormFieldRepository(dbPool: database.dbPool)
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "name", label: "Name", isRequired: true
        ))

        let recordRepo = RecordRepository(dbPool: database.dbPool)
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "A", formData: ["name": "Filled"]
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "B", formData: ["name": "Also Filled"]
        ))

        let result = try service.computeCompleteness(projectId: testProjectId)

        XCTAssertEqual(result.totalRecords, 2)
        XCTAssertEqual(result.completeCount, 2)
        XCTAssertEqual(result.completionPercentage, 1.0, accuracy: 0.01)
    }

    func testRecordsMissingRequiredFields() throws {
        let fieldRepo = FormFieldRepository(dbPool: database.dbPool)
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "soil", label: "Soil Type", isRequired: true
        ))
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "depth", label: "Depth", isRequired: true
        ))

        let recordRepo = RecordRepository(dbPool: database.dbPool)
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Complete", formData: ["soil": "clay", "depth": "2.5"]
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Missing Depth", formData: ["soil": "sand"]
        ))

        let result = try service.computeCompleteness(projectId: testProjectId)

        XCTAssertEqual(result.totalRecords, 2)
        XCTAssertEqual(result.completeCount, 1)
        XCTAssertEqual(result.incompleteCount, 1)

        let typeResult = result.typeCompleteness.first!
        XCTAssertEqual(typeResult.incompleteRecords.count, 1)
        XCTAssertEqual(typeResult.incompleteRecords[0].missingFields, ["Depth"])
    }

    func testDraftsCountedSeparately() throws {
        let recordRepo = RecordRepository(dbPool: database.dbPool)
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Normal"
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Draft", isDraft: true
        ))

        let result = try service.computeCompleteness(projectId: testProjectId)

        XCTAssertEqual(result.totalRecords, 2)
        XCTAssertEqual(result.draftCount, 1)
        XCTAssertEqual(result.completeCount, 1)
    }

    func testMultipleRecordTypes() throws {
        let typeRepo = RecordTypeRepository(dbPool: database.dbPool)
        let type2 = try typeRepo.create(RecordType(projectId: testProjectId, name: "Trench"))
        guard let type2Id = type2.id else {
            XCTFail("Type should have ID")
            return
        }

        let templateRepo = FormTemplateRepository(dbPool: database.dbPool)
        let template2 = try templateRepo.create(FormTemplate(recordTypeId: type2Id, name: "Trench Form"))

        let fieldRepo = FormFieldRepository(dbPool: database.dbPool)
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "f1", label: "Field 1", isRequired: true
        ))
        try fieldRepo.create(FormField(
            formTemplateId: template2.id!, name: "f2", label: "Field 2", isRequired: true
        ))

        let recordRepo = RecordRepository(dbPool: database.dbPool)
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: testTypeId,
            name: "Site A", formData: ["f1": "filled"]
        ))
        try recordRepo.create(Record(
            projectId: testProjectId, recordTypeId: type2Id,
            name: "Trench 1", formData: [:]
        ))

        let result = try service.computeCompleteness(projectId: testProjectId)

        XCTAssertEqual(result.typeCompleteness.count, 2)

        let siteType = result.typeCompleteness.first { $0.recordType.name == "Site" }
        XCTAssertEqual(siteType?.completionPercentage, 1.0, accuracy: 0.01)

        let trenchType = result.typeCompleteness.first { $0.recordType.name == "Trench" }
        XCTAssertEqual(trenchType?.completionPercentage, 0.0, accuracy: 0.01)
    }
}
