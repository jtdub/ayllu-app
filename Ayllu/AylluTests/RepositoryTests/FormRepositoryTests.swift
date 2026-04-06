import XCTest
@testable import Ayllu

final class FormRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepo: ProjectRepository!
    var typeRepo: RecordTypeRepository!
    var templateRepo: FormTemplateRepository!
    var fieldRepo: FormFieldRepository!
    var testProjectId: Int64!
    var testTypeId: Int64!
    var testTemplateId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepo = ProjectRepository(dbPool: database.dbPool)
        typeRepo = RecordTypeRepository(dbPool: database.dbPool)
        templateRepo = FormTemplateRepository(dbPool: database.dbPool)
        fieldRepo = FormFieldRepository(dbPool: database.dbPool)

        let project = try projectRepo.create(Project(name: "Test Project"))
        testProjectId = project.id

        let recordType = try typeRepo.create(RecordType(projectId: testProjectId, name: "Site"))
        testTypeId = recordType.id

        let template = try templateRepo.create(FormTemplate(
            recordTypeId: testTypeId,
            name: "Site Form"
        ))
        testTemplateId = template.id
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepo = nil
        typeRepo = nil
        templateRepo = nil
        fieldRepo = nil
    }

    // MARK: - FormTemplate Tests

    func testCreateTemplate() throws {
        let type2 = try typeRepo.create(RecordType(projectId: testProjectId, name: "Trench"))
        guard let type2Id = type2.id else {
            XCTFail("Type should have an ID")
            return
        }

        let template = try templateRepo.create(FormTemplate(
            recordTypeId: type2Id,
            name: "Trench Form",
            description: "Recording sheet"
        ))

        XCTAssertNotNil(template.id)
        XCTAssertEqual(template.name, "Trench Form")
        XCTAssertEqual(template.version, 1)
    }

    func testFetchByRecordType() throws {
        let fetched = try templateRepo.fetchByRecordType(testTypeId)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Site Form")
    }

    func testIncrementVersion() throws {
        let updated = try templateRepo.incrementVersion(testTemplateId)
        XCTAssertEqual(updated?.version, 2)
    }

    func testFetchWithFields() throws {
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId,
            name: "soil_type",
            label: "Soil Type",
            fieldType: .dropdown,
            options: ["Clay", "Sand", "Silt"],
            sortOrder: 0
        ))
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId,
            name: "depth",
            label: "Depth (m)",
            fieldType: .number,
            isRequired: true,
            sortOrder: 1
        ))

        let result = try templateRepo.fetchWithFields(testTemplateId)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0.name, "Site Form")
        XCTAssertEqual(result?.1.count, 2)
        XCTAssertEqual(result?.1[0].name, "soil_type")
        XCTAssertEqual(result?.1[1].name, "depth")
    }

    func testFetchWithFieldsByRecordType() throws {
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId,
            name: "name",
            label: "Site Name",
            fieldType: .text
        ))

        let result = try templateRepo.fetchWithFieldsByRecordType(testTypeId)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.1.count, 1)
    }

    // MARK: - FormField Tests

    func testCreateField() throws {
        let field = try fieldRepo.create(FormField(
            formTemplateId: testTemplateId,
            name: "soil_type",
            label: "Soil Type",
            fieldType: .dropdown,
            isRequired: true,
            options: ["Clay", "Sand", "Silt"],
            validationRules: [:],
            sortOrder: 0
        ))

        XCTAssertNotNil(field.id)
        XCTAssertEqual(field.name, "soil_type")
        XCTAssertEqual(field.fieldType, .dropdown)
        XCTAssertTrue(field.isRequired)
        XCTAssertEqual(field.options, ["Clay", "Sand", "Silt"])
    }

    func testFieldJSONRoundTrip() throws {
        let created = try fieldRepo.create(FormField(
            formTemplateId: testTemplateId,
            name: "count",
            label: "Count",
            fieldType: .number,
            validationRules: ["min": "0", "max": "999"],
            sortOrder: 0
        ))
        guard let id = created.id else {
            XCTFail("Field should have an ID")
            return
        }

        let fetched = try fieldRepo.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.validationRules["min"], "0")
        XCTAssertEqual(fetched?.validationRules["max"], "999")
    }

    func testBatchCreate() throws {
        let fields = [
            FormField(formTemplateId: testTemplateId, name: "a", label: "A", sortOrder: 0),
            FormField(formTemplateId: testTemplateId, name: "b", label: "B", sortOrder: 1),
            FormField(formTemplateId: testTemplateId, name: "c", label: "C", sortOrder: 2)
        ]

        let created = try fieldRepo.batchCreate(fields)
        XCTAssertEqual(created.count, 3)

        let all = try fieldRepo.fetchAll(formTemplateId: testTemplateId)
        XCTAssertEqual(all.count, 3)
    }

    func testReorderFields() throws {
        let first = try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "a", label: "A", sortOrder: 0
        ))
        let second = try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "b", label: "B", sortOrder: 1
        ))
        guard let firstId = first.id, let secondId = second.id else {
            XCTFail("Fields should have IDs")
            return
        }

        try fieldRepo.reorder(ids: [secondId, firstId])

        let reordered = try fieldRepo.fetchAll(formTemplateId: testTemplateId)
        XCTAssertEqual(reordered[0].name, "b")
        XCTAssertEqual(reordered[1].name, "a")
    }

    func testDeleteField() throws {
        let field = try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "a", label: "A"
        ))
        guard let id = field.id else {
            XCTFail("Field should have an ID")
            return
        }

        try fieldRepo.delete(id: id)

        let count = try fieldRepo.countForTemplate(testTemplateId)
        XCTAssertEqual(count, 0)
    }

    func testDeleteAllFields() throws {
        try fieldRepo.create(FormField(formTemplateId: testTemplateId, name: "a", label: "A"))
        try fieldRepo.create(FormField(formTemplateId: testTemplateId, name: "b", label: "B"))

        try fieldRepo.deleteAll(formTemplateId: testTemplateId)

        let count = try fieldRepo.countForTemplate(testTemplateId)
        XCTAssertEqual(count, 0)
    }

    // MARK: - Cascade Delete

    func testDeletingRecordTypeCascadesToTemplate() throws {
        try typeRepo.permanentlyDelete(id: testTypeId)

        let template = try templateRepo.fetchByRecordType(testTypeId)
        XCTAssertNil(template)
    }

    func testDeletingTemplateCascadesToFields() throws {
        try fieldRepo.create(FormField(
            formTemplateId: testTemplateId, name: "a", label: "A"
        ))

        try templateRepo.delete(id: testTemplateId)

        let fields = try fieldRepo.fetchAll(formTemplateId: testTemplateId)
        XCTAssertEqual(fields.count, 0)
    }
}
