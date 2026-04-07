import XCTest
@testable import Ayllu

final class GPXImportServiceTests: XCTestCase {
    func testParseMinimalWaypoint() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
          <wpt lat="37.7749" lon="-122.4194">
            <name>Test Point</name>
          </wpt>
        </gpx>
        """
        let data = gpx.data(using: .utf8)!
        let items = try GPXImportService.parse(data: data)

        XCTAssertEqual(items.count, 1)
        guard case .waypoint(let wp) = items[0] else {
            XCTFail("Expected waypoint")
            return
        }
        XCTAssertEqual(wp.name, "Test Point")
        XCTAssertEqual(wp.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(wp.longitude, -122.4194, accuracy: 0.0001)
    }

    func testParseMultipleWaypoints() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
          <wpt lat="37.0" lon="-122.0"><name>A</name></wpt>
          <wpt lat="38.0" lon="-121.0"><name>B</name></wpt>
          <wpt lat="39.0" lon="-120.0"><name>C</name></wpt>
        </gpx>
        """
        let items = try GPXImportService.parse(data: gpx.data(using: .utf8)!)
        XCTAssertEqual(items.count, 3)
    }

    func testParseWaypointWithElevation() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
          <wpt lat="37.0" lon="-122.0">
            <name>High Point</name>
            <ele>1_500.5</ele>
            <desc>A description</desc>
          </wpt>
        </gpx>
        """
        let items = try GPXImportService.parse(data: gpx.data(using: .utf8)!)
        guard case .waypoint(let wp) = items[0] else {
            XCTFail("Expected waypoint")
            return
        }
        XCTAssertEqual(wp.altitude ?? 0, 1_500.5, accuracy: 0.1)
        XCTAssertEqual(wp.description, "A description")
    }

    func testParseEmptyGPX() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
        </gpx>
        """
        let items = try GPXImportService.parse(data: gpx.data(using: .utf8)!)
        XCTAssertTrue(items.isEmpty)
    }

    func testParseInvalidData() {
        let data = Data("not xml at all".utf8)
        XCTAssertThrowsError(try GPXImportService.parse(data: data))
    }

    func testParseWaypointWithDefaultName() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
          <wpt lat="37.0" lon="-122.0"></wpt>
        </gpx>
        """
        let items = try GPXImportService.parse(data: gpx.data(using: .utf8)!)
        guard case .waypoint(let wp) = items[0] else {
            XCTFail("Expected waypoint")
            return
        }
        XCTAssertEqual(wp.name, "Imported Waypoint")
    }
}
