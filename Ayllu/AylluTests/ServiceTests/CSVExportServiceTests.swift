import XCTest
@testable import Ayllu

final class CSVExportServiceTests: XCTestCase {
    func testExportBasicRecords() {
        let records = [
            Record(
                projectId: 1,
                recordTypeId: 1,
                name: "Site A",
                description: "First site",
                latitude: 37.7749,
                longitude: -122.4194,
                formData: ["soil_type": "Clay", "depth": "2.5"]
            )
        ]

        let fields = [
            FormField(formTemplateId: 1, name: "soil_type", label: "Soil Type"),
            FormField(formTemplateId: 1, name: "depth", label: "Depth")
        ]

        let csv = CSVExportService.export(
            records: records,
            fields: fields,
            projectName: "Test"
        )

        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2) // header + 1 data row

        // Check header
        XCTAssertTrue(lines[0].contains("Name"))
        XCTAssertTrue(lines[0].contains("Soil Type"))
        XCTAssertTrue(lines[0].contains("Depth"))

        // Check data row
        XCTAssertTrue(lines[1].contains("Site A"))
        XCTAssertTrue(lines[1].contains("Clay"))
        XCTAssertTrue(lines[1].contains("2.5"))
    }

    func testExportEmptyRecords() {
        let csv = CSVExportService.export(records: [], fields: [], projectName: "Empty")

        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 1) // header only
    }

    func testExportEscapesCSVSpecialCharacters() {
        let records = [
            Record(
                projectId: 1,
                recordTypeId: 1,
                name: "Site with, comma",
                formData: ["notes": "Has \"quotes\" inside"]
            )
        ]

        let fields = [
            FormField(formTemplateId: 1, name: "notes", label: "Notes")
        ]

        let csv = CSVExportService.export(
            records: records,
            fields: fields,
            projectName: "Test"
        )

        // Commas in values should be quoted
        XCTAssertTrue(csv.contains("\"Site with, comma\""))
        // Quotes should be escaped
        XCTAssertTrue(csv.contains("\"\"quotes\"\""))
    }

    func testExportMultipleRecords() {
        let records = [
            Record(projectId: 1, recordTypeId: 1, name: "A", formData: ["v": "1"]),
            Record(projectId: 1, recordTypeId: 1, name: "B", formData: ["v": "2"]),
            Record(projectId: 1, recordTypeId: 1, name: "C", formData: ["v": "3"])
        ]

        let fields = [FormField(formTemplateId: 1, name: "v", label: "Value")]

        let csv = CSVExportService.export(records: records, fields: fields, projectName: "Test")
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 4) // header + 3 data rows
    }

    func testExportToFile() {
        let records = [
            Record(projectId: 1, recordTypeId: 1, name: "Test", formData: [:])
        ]

        let url = CSVExportService.exportToFile(
            records: records,
            fields: [],
            projectName: "Test Project"
        )

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.lastPathComponent.contains("Test_Project"))
        XCTAssertEqual(url!.pathExtension, "csv")

        // Cleanup
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func testExportMissingFormData() {
        let records = [
            Record(projectId: 1, recordTypeId: 1, name: "Sparse", formData: ["a": "1"])
        ]

        let fields = [
            FormField(formTemplateId: 1, name: "a", label: "A"),
            FormField(formTemplateId: 1, name: "b", label: "B")
        ]

        let csv = CSVExportService.export(records: records, fields: fields, projectName: "Test")
        let lines = csv.components(separatedBy: "\n")
        let dataRow = lines[1]

        // Should contain value for 'a' and empty for 'b'
        XCTAssertTrue(dataRow.contains("1"))
    }
}
