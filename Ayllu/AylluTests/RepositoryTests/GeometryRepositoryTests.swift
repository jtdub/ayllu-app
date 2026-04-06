import XCTest
import CoreLocation
@testable import Ayllu

final class GeometryRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepo: ProjectRepository!
    var repository: GeometryRepository!
    var testProjectId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepo = ProjectRepository(dbPool: database.dbPool)
        repository = GeometryRepository(dbPool: database.dbPool)

        let project = try projectRepo.create(Project(name: "Test Project"))
        testProjectId = project.id
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepo = nil
        repository = nil
        testProjectId = nil
    }

    // MARK: - Create

    func testCreatePolygon() throws {
        let geometry = Geometry(
            projectId: testProjectId,
            name: "Test Polygon",
            description: "A test area",
            geometryType: .polygon,
            coordinates: [[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0], [-121.0, 37.0]],
            area: 10_000,
            perimeter: 400,
            fillColor: "#007AFF40",
            strokeColor: "#007AFF"
        )
        let created = try repository.create(geometry)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "Test Polygon")
        XCTAssertEqual(created.geometryType, .polygon)
        XCTAssertEqual(created.coordinates.count, 4)
        XCTAssertEqual(created.area, 10_000)
    }

    func testCreatePolyline() throws {
        let geometry = Geometry(
            projectId: testProjectId,
            name: "Test Line",
            geometryType: .polyline,
            coordinates: [[-122.0, 37.0], [-121.5, 37.5], [-121.0, 38.0]],
            perimeter: 150
        )
        let created = try repository.create(geometry)

        XCTAssertEqual(created.geometryType, .polyline)
        XCTAssertEqual(created.coordinates.count, 3)
    }

    func testCoordinatesJSONRoundTrip() throws {
        let coords: [[Double]] = [[-122.4194, 37.7749], [-122.4000, 37.7800], [-122.4100, 37.7700]]
        let created = try repository.create(Geometry(
            projectId: testProjectId,
            name: "Coords Test",
            geometryType: .polygon,
            coordinates: coords
        ))
        guard let id = created.id else {
            XCTFail("Geometry should have an ID")
            return
        }

        let fetched = try repository.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.coordinates.count, 3)
        XCTAssertEqual(fetched?.coordinates[0][0], -122.4194, accuracy: 0.0001)
        XCTAssertEqual(fetched?.coordinates[0][1], 37.7749, accuracy: 0.0001)
    }

    func testVerticesCreatedAutomatically() throws {
        let created = try repository.create(Geometry(
            projectId: testProjectId,
            name: "Vertices Test",
            geometryType: .polygon,
            coordinates: [[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0]]
        ))
        guard let id = created.id else {
            XCTFail("Geometry should have an ID")
            return
        }

        let vertices = try repository.fetchVertices(geometryId: id)
        XCTAssertEqual(vertices.count, 3)
        XCTAssertEqual(vertices[0].sortOrder, 0)
        XCTAssertEqual(vertices[1].sortOrder, 1)
        XCTAssertEqual(vertices[2].sortOrder, 2)
    }

    // MARK: - Read

    func testFetchAll() throws {
        try repository.create(Geometry(
            projectId: testProjectId, name: "A", geometryType: .polygon, coordinates: []
        ))
        try repository.create(Geometry(
            projectId: testProjectId, name: "B", geometryType: .polyline, coordinates: []
        ))

        let results = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(results.count, 2)
    }

    func testFetchByRecord() throws {
        let typeRepo = RecordTypeRepository(dbPool: database.dbPool)
        let recordType = try typeRepo.create(RecordType(projectId: testProjectId, name: "Site"))
        let recordRepo = RecordRepository(dbPool: database.dbPool)
        let record = try recordRepo.create(Record(
            projectId: testProjectId,
            recordTypeId: recordType.id!,
            name: "Test Site"
        ))
        guard let recordId = record.id else {
            XCTFail("Record should have an ID")
            return
        }

        try repository.create(Geometry(
            projectId: testProjectId,
            recordId: recordId,
            name: "Site Boundary",
            geometryType: .polygon,
            coordinates: [[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0]]
        ))
        try repository.create(Geometry(
            projectId: testProjectId,
            name: "Unlinked",
            geometryType: .polyline,
            coordinates: []
        ))

        let linked = try repository.fetchByRecord(recordId)
        XCTAssertEqual(linked.count, 1)
        XCTAssertEqual(linked[0].name, "Site Boundary")
    }

    // MARK: - Update

    func testUpdate() throws {
        var created = try repository.create(Geometry(
            projectId: testProjectId,
            name: "Original",
            geometryType: .polygon,
            coordinates: [[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0]]
        ))
        created.name = "Updated"
        created.coordinates.append([-121.0, 37.0])
        created.area = 12_345

        let updated = try repository.update(created)
        XCTAssertEqual(updated.name, "Updated")

        let fetched = try repository.fetchById(updated.id!)
        XCTAssertEqual(fetched?.coordinates.count, 4)
        XCTAssertEqual(fetched?.area, 12_345)

        // Vertices should be updated too
        let vertices = try repository.fetchVertices(geometryId: updated.id!)
        XCTAssertEqual(vertices.count, 4)
    }

    // MARK: - Delete

    func testSoftDelete() throws {
        let created = try repository.create(Geometry(
            projectId: testProjectId, name: "Delete Me", geometryType: .polygon, coordinates: []
        ))
        guard let id = created.id else {
            XCTFail("Geometry should have an ID")
            return
        }

        try repository.delete(id: id)

        let results = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Count

    func testCountForProject() throws {
        try repository.create(Geometry(
            projectId: testProjectId, name: "A", geometryType: .polygon, coordinates: []
        ))
        try repository.create(Geometry(
            projectId: testProjectId, name: "B", geometryType: .polyline, coordinates: []
        ))

        let count = try repository.countForProject(testProjectId)
        XCTAssertEqual(count, 2)
    }

    // MARK: - GeoJSON

    func testToGeoJSONPolygon() {
        let geometry = Geometry(
            projectId: 1,
            name: "Test",
            geometryType: .polygon,
            coordinates: [[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0]]
        )
        let json = geometry.toGeoJSON()
        XCTAssertTrue(json.contains("\"type\":\"Polygon\""))
        XCTAssertTrue(json.contains("\"name\":\"Test\""))
    }

    func testToGeoJSONWithSpecialCharactersInName() {
        let geometry = Geometry(
            projectId: 1,
            name: "Site \"Alpha\" — L'excavation\nnewline",
            geometryType: .polygon,
            coordinates: [[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0]]
        )
        let json = geometry.toGeoJSON()
        // Should produce valid JSON despite special characters
        let data = json.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(parsed, "GeoJSON with special chars should be valid JSON")

        let properties = parsed?["properties"] as? [String: Any]
        let name = properties?["name"] as? String
        XCTAssertTrue(name?.contains("Alpha") ?? false)
    }

    func testToGeoJSONPolyline() {
        let geometry = Geometry(
            projectId: 1,
            name: "Trail",
            geometryType: .polyline,
            coordinates: [[-122.0, 37.0], [-121.0, 38.0]]
        )
        let json = geometry.toGeoJSON()
        XCTAssertTrue(json.contains("\"type\":\"LineString\""))
    }

    func testCLLocationCoordinatesConversion() {
        let geometry = Geometry(
            projectId: 1,
            name: "Test",
            geometryType: .polygon,
            coordinates: [[-122.4194, 37.7749], [-122.4000, 37.7800]]
        )

        let coords = geometry.clLocationCoordinates
        XCTAssertEqual(coords.count, 2)
        XCTAssertEqual(coords[0].latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(coords[0].longitude, -122.4194, accuracy: 0.0001)
    }
}
