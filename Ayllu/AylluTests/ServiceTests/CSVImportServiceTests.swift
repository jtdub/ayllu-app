import XCTest
@testable import Ayllu

final class CSVImportServiceTests: XCTestCase {
    func testParseHeaders() throws {
        let csv = "Name,Latitude,Longitude,Description\nSite A,37.0,-122.0,A site\n"
        let result = try CSVImportService.parseHeaders(data: csv.data(using: .utf8)!)

        XCTAssertEqual(result.headers, ["Name", "Latitude", "Longitude", "Description"])
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0], ["Site A", "37.0", "-122.0", "A site"])
    }

    func testMapToItems() throws {
        let headers = ["Name", "Lat", "Lon", "Desc"]
        let rows = [
            ["Site A", "37.7749", "-122.4194", "First site"],
            ["Site B", "38.0", "-121.0", "Second site"]
        ]
        let mapping = CSVColumnMapping(
            nameColumn: "Name",
            latitudeColumn: "Lat",
            longitudeColumn: "Lon",
            descriptionColumn: "Desc"
        )

        let items = CSVImportService.mapToItems(rows: rows, headers: headers, mapping: mapping)
        XCTAssertEqual(items.count, 2)

        guard case .waypoint(let wp) = items[0] else {
            XCTFail("Expected waypoint")
            return
        }
        XCTAssertEqual(wp.name, "Site A")
        XCTAssertEqual(wp.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(wp.description, "First site")
    }

    func testQuotedFieldsWithCommas() {
        let line = "\"Site A, Phase 1\",37.0,-122.0,\"A site, with comma\""
        let fields = CSVImportService.parseCSVLine(line)

        XCTAssertEqual(fields.count, 4)
        XCTAssertEqual(fields[0], "Site A, Phase 1")
        XCTAssertEqual(fields[3], "A site, with comma")
    }

    func testEmptyFile() {
        let data = Data("".utf8)
        XCTAssertThrowsError(try CSVImportService.parseHeaders(data: data))
    }

    func testHeadersOnly() {
        let csv = "Name,Lat,Lon\n"
        let data = csv.data(using: .utf8)!
        XCTAssertThrowsError(try CSVImportService.parseHeaders(data: data))
    }

    func testSkipsRowsWithInvalidCoordinates() {
        let headers = ["Name", "Lat", "Lon"]
        let rows = [
            ["Valid", "37.0", "-122.0"],
            ["Invalid", "not-a-number", "-122.0"],
            ["Also Valid", "38.0", "-121.0"]
        ]
        let mapping = CSVColumnMapping(
            nameColumn: "Name",
            latitudeColumn: "Lat",
            longitudeColumn: "Lon"
        )

        let items = CSVImportService.mapToItems(rows: rows, headers: headers, mapping: mapping)
        XCTAssertEqual(items.count, 2)
    }

    func testSkipsRowsWithEmptyName() {
        let headers = ["Name", "Lat", "Lon"]
        let rows = [
            ["", "37.0", "-122.0"],
            ["Valid", "38.0", "-121.0"]
        ]
        let mapping = CSVColumnMapping(
            nameColumn: "Name",
            latitudeColumn: "Lat",
            longitudeColumn: "Lon"
        )

        let items = CSVImportService.mapToItems(rows: rows, headers: headers, mapping: mapping)
        XCTAssertEqual(items.count, 1)
    }

    func testOptionalAltitudeColumn() {
        let headers = ["Name", "Lat", "Lon", "Alt"]
        let rows = [["Site A", "37.0", "-122.0", "1_500.5"]]
        let mapping = CSVColumnMapping(
            nameColumn: "Name",
            latitudeColumn: "Lat",
            longitudeColumn: "Lon",
            altitudeColumn: "Alt"
        )

        let items = CSVImportService.mapToItems(rows: rows, headers: headers, mapping: mapping)
        guard case .waypoint(let wp) = items[0] else {
            XCTFail("Expected waypoint")
            return
        }
        XCTAssertEqual(wp.altitude, 1_500.5, accuracy: 0.1)
    }
}
