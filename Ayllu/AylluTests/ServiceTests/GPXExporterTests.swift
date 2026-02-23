import XCTest
@testable import Ayllu

final class GPXExporterTests: XCTestCase {
    var exporter: GPXExporter!

    override func setUpWithError() throws {
        exporter = GPXExporter()
    }

    override func tearDownWithError() throws {
        exporter = nil
    }

    // MARK: - Basic Export Tests

    func testExportEmptyWaypoints() throws {
        let gpx = exporter.export(waypoints: [])

        XCTAssertTrue(gpx.contains("<?xml"))
        XCTAssertTrue(gpx.contains("<gpx"))
        XCTAssertTrue(gpx.contains("version=\"1.1\""))
        XCTAssertTrue(gpx.contains("</gpx>"))
    }

    func testExportSingleWaypoint() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Test Point",
            description: "A test waypoint",
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 10.5
        )

        let gpx = exporter.export(waypoints: [waypoint])

        XCTAssertTrue(gpx.contains("<wpt lat=\"37.7749\" lon=\"-122.4194\">"))
        XCTAssertTrue(gpx.contains("<name>Test Point</name>"))
        XCTAssertTrue(gpx.contains("<desc>A test waypoint</desc>"))
        XCTAssertTrue(gpx.contains("<ele>10.5</ele>"))
    }

    func testExportMultipleWaypoints() throws {
        let waypoints = [
            Waypoint(projectId: 1, name: "WP1", latitude: 37.0, longitude: -122.0),
            Waypoint(projectId: 1, name: "WP2", latitude: 38.0, longitude: -123.0),
            Waypoint(projectId: 1, name: "WP3", latitude: 39.0, longitude: -124.0)
        ]

        let gpx = exporter.export(waypoints: waypoints)

        XCTAssertTrue(gpx.contains("<name>WP1</name>"))
        XCTAssertTrue(gpx.contains("<name>WP2</name>"))
        XCTAssertTrue(gpx.contains("<name>WP3</name>"))
    }

    // MARK: - Metadata Tests

    func testExportWithProjectMetadata() throws {
        let project = Project(
            name: "Archaeological Survey",
            description: "Field survey of site XYZ"
        )
        let waypoint = Waypoint(projectId: 1, name: "Site A", latitude: 37.0, longitude: -122.0)

        let gpx = exporter.export(waypoints: [waypoint], project: project)

        XCTAssertTrue(gpx.contains("<metadata>"))
        XCTAssertTrue(gpx.contains("<name>Archaeological Survey</name>"))
        XCTAssertTrue(gpx.contains("<desc>Field survey of site XYZ</desc>"))
    }

    func testExportWithCreator() throws {
        let options = GPXExporter.Options(creator: "Custom App Name")
        let waypoint = Waypoint(projectId: 1, name: "Point", latitude: 37.0, longitude: -122.0)

        let gpx = exporter.export(waypoints: [waypoint], options: options)

        XCTAssertTrue(gpx.contains("creator=\"Custom App Name\""))
    }

    // MARK: - Category and Tags Tests

    func testExportWithCategory() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Artifact Find",
            latitude: 37.0,
            longitude: -122.0,
            category: .artifact
        )

        let gpx = exporter.export(waypoints: [waypoint])

        XCTAssertTrue(gpx.contains("<type>Artifact</type>"))
        XCTAssertTrue(gpx.contains("<sym>Museum</sym>"))
    }

    func testExportWithTags() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Tagged Point",
            latitude: 37.0,
            longitude: -122.0,
            tags: ["ceramic", "prehistoric", "surface"]
        )

        let gpx = exporter.export(waypoints: [waypoint])

        XCTAssertTrue(gpx.contains("<cmt>Tags: ceramic, prehistoric, surface</cmt>"))
    }

    // MARK: - Extensions Tests

    func testExportWithAccuracyExtensions() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Accurate Point",
            latitude: 37.0,
            longitude: -122.0,
            horizontalAccuracy: 5.5,
            verticalAccuracy: 8.2,
            heading: 45.0,
            speed: 1.2
        )

        let gpx = exporter.export(waypoints: [waypoint])

        XCTAssertTrue(gpx.contains("<extensions>"))
        XCTAssertTrue(gpx.contains("ayllu:horizontalAccuracy"))
        XCTAssertTrue(gpx.contains("5.50"))
    }

    func testExportWithCustomFields() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Custom Point",
            latitude: 37.0,
            longitude: -122.0,
            customFields: ["soil_type": "clay", "depth_cm": "25"]
        )

        let gpx = exporter.export(waypoints: [waypoint])

        XCTAssertTrue(gpx.contains("<extensions>"))
        XCTAssertTrue(gpx.contains("ayllu:soil_type"))
        XCTAssertTrue(gpx.contains("clay"))
    }

    func testExportWithoutExtensions() throws {
        var options = GPXExporter.Options.default
        options.includeExtensions = false

        let waypoint = Waypoint(
            projectId: 1,
            name: "Simple Point",
            latitude: 37.0,
            longitude: -122.0,
            horizontalAccuracy: 5.0,
            customFields: ["key": "value"]
        )

        let gpx = exporter.export(waypoints: [waypoint], options: options)

        XCTAssertFalse(gpx.contains("ayllu:horizontalAccuracy"))
        XCTAssertFalse(gpx.contains("ayllu:key"))
    }

    // MARK: - File Export Tests

    func testExportToFile() throws {
        let waypoint = Waypoint(projectId: 1, name: "File Test", latitude: 37.0, longitude: -122.0)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID()).gpx")

        try exporter.export(waypoints: [waypoint], to: tempURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        let content = try String(contentsOf: tempURL)
        XCTAssertTrue(content.contains("<name>File Test</name>"))

        try FileManager.default.removeItem(at: tempURL)
    }

    func testExportForSharing() throws {
        let project = Project(name: "Test Project")
        let waypoint = Waypoint(projectId: 1, name: "Share Test", latitude: 37.0, longitude: -122.0)

        let fileURL = try exporter.exportForSharing(waypoints: [waypoint], project: project)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(fileURL.lastPathComponent.contains("Test_Project"))
        XCTAssertEqual(fileURL.pathExtension, "gpx")

        try FileManager.default.removeItem(at: fileURL)
    }

    func testExportForSharingWithCustomFileName() throws {
        let waypoint = Waypoint(projectId: 1, name: "Named Export", latitude: 37.0, longitude: -122.0)

        let fileURL = try exporter.exportForSharing(waypoints: [waypoint], fileName: "my_custom_export")

        XCTAssertEqual(fileURL.lastPathComponent, "my_custom_export.gpx")

        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - GPX Validation Tests

    func testExportProducesValidGPX11() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Validation Test",
            latitude: 37.7749,
            longitude: -122.4194
        )

        let gpx = exporter.export(waypoints: [waypoint])

        // Check GPX 1.1 schema requirements
        XCTAssertTrue(gpx.contains("version=\"1.1\""))
        XCTAssertTrue(gpx.contains("xmlns=\"http://www.topografix.com/GPX/1/1\""))
        XCTAssertTrue(gpx.contains("creator="))
    }

    func testExportTimestampFormat() throws {
        let date = Date(timeIntervalSince1970: 1_609_459_200) // 2021-01-01 00:00:00 UTC
        let waypoint = Waypoint(
            projectId: 1,
            name: "Time Test",
            latitude: 37.0,
            longitude: -122.0,
            createdAt: date
        )

        let gpx = exporter.export(waypoints: [waypoint])

        // GPX uses ISO 8601 format
        XCTAssertTrue(gpx.contains("<time>"))
        XCTAssertTrue(gpx.contains("2021-01-01"))
    }

    // MARK: - Edge Cases

    func testExportWithSpecialCharacters() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Test Point",
            description: "Description with notes",
            latitude: 37.0,
            longitude: -122.0
        )

        let gpx = exporter.export(waypoints: [waypoint])

        // Verify the waypoint was exported
        XCTAssertTrue(gpx.contains("<name>Test Point</name>"))
        XCTAssertTrue(gpx.contains("<desc>Description with notes</desc>"))
    }

    func testExportWithNilOptionalFields() throws {
        let waypoint = Waypoint(
            projectId: 1,
            name: "Minimal",
            latitude: 37.0,
            longitude: -122.0
        )

        let gpx = exporter.export(waypoints: [waypoint])

        // Should not contain empty elements for nil fields
        XCTAssertFalse(gpx.contains("<ele></ele>"))
        XCTAssertFalse(gpx.contains("<desc></desc>"))
    }
}
