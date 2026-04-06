import XCTest
@testable import Ayllu

final class FormRendererViewModelTests: XCTestCase {
    // MARK: - Required Field Validation

    func testRequiredFieldEmpty() {
        let fields = [FormField(formTemplateId: 1, name: "name", label: "Name", isRequired: true)]
        let vm = FormRendererViewModel(fields: fields)

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["name"], "Name is required")
        XCTAssertEqual(vm.firstErrorFieldName, "name")
    }

    func testRequiredFieldFilled() {
        let fields = [FormField(formTemplateId: 1, name: "name", label: "Name", isRequired: true)]
        let vm = FormRendererViewModel(fields: fields, values: ["name": "Test"])

        XCTAssertTrue(vm.validate())
        XCTAssertTrue(vm.validationErrors.isEmpty)
    }

    func testRequiredFieldWhitespaceOnly() {
        let fields = [FormField(formTemplateId: 1, name: "name", label: "Name", isRequired: true)]
        let vm = FormRendererViewModel(fields: fields, values: ["name": "   "])

        XCTAssertFalse(vm.validate())
        XCTAssertNotNil(vm.validationErrors["name"])
    }

    // MARK: - Draft Mode

    func testDraftSkipsRequired() {
        let fields = [FormField(formTemplateId: 1, name: "name", label: "Name", isRequired: true)]
        let vm = FormRendererViewModel(fields: fields)

        XCTAssertTrue(vm.validate(asDraft: true))
    }

    func testDraftStillChecksNumberFormat() {
        let fields = [FormField(
            formTemplateId: 1, name: "count", label: "Count",
            fieldType: .number,
            validationRules: ["min": "0"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["count": "-5"])

        XCTAssertFalse(vm.validate(asDraft: true))
        XCTAssertNotNil(vm.validationErrors["count"])
    }

    // MARK: - Number Validation

    func testNumberValid() {
        let fields = [FormField(
            formTemplateId: 1, name: "depth", label: "Depth",
            fieldType: .number,
            validationRules: ["min": "0", "max": "100"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["depth": "50"])

        XCTAssertTrue(vm.validate())
    }

    func testNumberBelowMin() {
        let fields = [FormField(
            formTemplateId: 1, name: "depth", label: "Depth",
            fieldType: .number,
            validationRules: ["min": "0"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["depth": "-1"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["depth"], "Depth must be at least 0")
    }

    func testNumberAboveMax() {
        let fields = [FormField(
            formTemplateId: 1, name: "depth", label: "Depth",
            fieldType: .number,
            validationRules: ["max": "100"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["depth": "150"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["depth"], "Depth must be at most 100")
    }

    func testNumberNotANumber() {
        let fields = [FormField(
            formTemplateId: 1, name: "depth", label: "Depth", fieldType: .number
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["depth": "abc"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["depth"], "Depth must be a number")
    }

    // MARK: - Text Length Validation

    func testTextMinLength() {
        let fields = [FormField(
            formTemplateId: 1, name: "code", label: "Code",
            fieldType: .text,
            validationRules: ["minLength": "3"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["code": "AB"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["code"], "Code must be at least 3 characters")
    }

    func testTextMaxLength() {
        let fields = [FormField(
            formTemplateId: 1, name: "code", label: "Code",
            fieldType: .text,
            validationRules: ["maxLength": "5"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["code": "ABCDEF"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["code"], "Code must be at most 5 characters")
    }

    func testTextLengthValid() {
        let fields = [FormField(
            formTemplateId: 1, name: "code", label: "Code",
            fieldType: .text,
            validationRules: ["minLength": "2", "maxLength": "5"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["code": "ABC"])

        XCTAssertTrue(vm.validate())
    }

    // MARK: - Regex Pattern Validation

    func testRegexValid() {
        let fields = [FormField(
            formTemplateId: 1, name: "site_id", label: "Site ID",
            fieldType: .text,
            validationRules: ["pattern": "^[A-Z]{2}-\\d+$"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["site_id": "AB-123"])

        XCTAssertTrue(vm.validate())
    }

    func testRegexInvalid() {
        let fields = [FormField(
            formTemplateId: 1, name: "site_id", label: "Site ID",
            fieldType: .text,
            validationRules: [
                "pattern": "^[A-Z]{2}-\\d+$",
                "patternMessage": "Must match format XX-123"
            ]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["site_id": "bad"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["site_id"], "Must match format XX-123")
    }

    func testRegexInvalidPatternDoesNotCrash() {
        let fields = [FormField(
            formTemplateId: 1, name: "test", label: "Test",
            fieldType: .text,
            validationRules: ["pattern": "[invalid"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["test": "anything"])

        // Invalid regex should be silently skipped, not crash
        XCTAssertTrue(vm.validate())
    }

    // MARK: - GPS Coordinate Validation

    func testGPSValid() {
        let fields = [FormField(
            formTemplateId: 1, name: "location", label: "Location",
            fieldType: .gpsCoordinates
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["location": "37.7749, -122.4194"])

        XCTAssertTrue(vm.validate())
    }

    func testGPSInvalidLatitude() {
        let fields = [FormField(
            formTemplateId: 1, name: "location", label: "Location",
            fieldType: .gpsCoordinates
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["location": "95.0, -122.0"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["location"], "Latitude must be between -90 and 90")
    }

    func testGPSInvalidLongitude() {
        let fields = [FormField(
            formTemplateId: 1, name: "location", label: "Location",
            fieldType: .gpsCoordinates
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["location": "37.0, -200.0"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["location"], "Longitude must be between -180 and 180")
    }

    func testGPSMissingComma() {
        let fields = [FormField(
            formTemplateId: 1, name: "location", label: "Location",
            fieldType: .gpsCoordinates
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["location": "37.0"])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["location"], "Location must be latitude, longitude")
    }

    // MARK: - Date Validation

    func testDateNoFuture() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowStr = FormRendererViewModel.displayDateFormatter.string(from: tomorrow)

        let fields = [FormField(
            formTemplateId: 1, name: "date", label: "Date",
            fieldType: .date,
            validationRules: ["noFutureDates": "true"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["date": tomorrowStr])

        XCTAssertFalse(vm.validate())
        XCTAssertEqual(vm.validationErrors["date"], "Date cannot be a future date")
    }

    func testDateTodayIsValid() {
        let today = Date()
        let todayStr = FormRendererViewModel.displayDateFormatter.string(from: today)

        let fields = [FormField(
            formTemplateId: 1, name: "date", label: "Date",
            fieldType: .date,
            validationRules: ["noFutureDates": "true"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["date": todayStr])

        XCTAssertTrue(vm.validate())
    }

    func testDatePastIsValid() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStr = FormRendererViewModel.displayDateFormatter.string(from: yesterday)

        let fields = [FormField(
            formTemplateId: 1, name: "date", label: "Date",
            fieldType: .date,
            validationRules: ["noFutureDates": "true"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: ["date": yesterdayStr])

        XCTAssertTrue(vm.validate())
    }

    // MARK: - Error Tracking

    func testFirstErrorFieldName() {
        let fields = [
            FormField(formTemplateId: 1, name: "a", label: "A", isRequired: true, sortOrder: 0),
            FormField(formTemplateId: 1, name: "b", label: "B", isRequired: true, sortOrder: 1)
        ]
        let vm = FormRendererViewModel(fields: fields)

        vm.validate()
        XCTAssertEqual(vm.firstErrorFieldName, "a")
    }

    func testClearErrorOnEdit() {
        let fields = [FormField(formTemplateId: 1, name: "name", label: "Name", isRequired: true)]
        let vm = FormRendererViewModel(fields: fields)

        vm.validate()
        XCTAssertNotNil(vm.validationErrors["name"])

        vm.setValue(for: fields[0], value: "Filled")
        XCTAssertNil(vm.validationErrors["name"])
    }

    // MARK: - Empty Optional Fields

    func testOptionalEmptyFieldSkipsValidation() {
        let fields = [FormField(
            formTemplateId: 1, name: "depth", label: "Depth",
            fieldType: .number,
            isRequired: false,
            validationRules: ["min": "0"]
        )]
        let vm = FormRendererViewModel(fields: fields, values: [:])

        XCTAssertTrue(vm.validate())
    }
}
