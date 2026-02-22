import XCTest
@testable import Ayllu
import GRDB
import CoreLocation

final class WaypointRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepo: ProjectRepository!
    var repository: WaypointRepository!
    var testProjectId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepo = ProjectRepository(dbPool: database.dbPool)
        repository = WaypointRepository(dbPool: database.dbPool)

        // Create a test project
        let project = try projectRepo.create(Project(name: "Test Project"))
        testProjectId = project.id
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepo = nil
        repository = nil
    }

    // MARK: - Create Tests

    func testCreateWaypoint() throws {
        let waypoint = Waypoint(
            projectId: testProjectId,
            name: "Test Waypoint",
            description: "A test waypoint",
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100
        )
        let created = try repository.create(waypoint)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "Test Waypoint")
        XCTAssertEqual(created.latitude, 37.7749)
        XCTAssertEqual(created.longitude, -122.4194)
        XCTAssertEqual(created.altitude, 100)
    }

    func testCreateQuickWaypoint() throws {
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let created = try repository.createQuick(
            projectId: testProjectId,
            location: location,
            category: .site
        )

        XCTAssertNotNil(created.id)
        XCTAssertTrue(created.name.hasPrefix("WP-"))
        XCTAssertEqual(created.latitude, 40.7128)
        XCTAssertEqual(created.longitude, -74.0060)
        XCTAssertEqual(created.category, .site)
    }

    func testCreateWaypointWithTags() throws {
        let waypoint = Waypoint(
            projectId: testProjectId,
            name: "Tagged WP",
            latitude: 0,
            longitude: 0,
            tags: ["important", "review", "site-a"]
        )
        let created = try repository.create(waypoint)
        let fetched = try repository.fetchById(created.id!)

        XCTAssertEqual(fetched?.tags.count, 3)
        XCTAssertTrue(fetched?.tags.contains("important") ?? false)
    }

    func testCreateWaypointWithCustomFields() throws {
        let waypoint = Waypoint(
            projectId: testProjectId,
            name: "Custom WP",
            latitude: 0,
            longitude: 0,
            customFields: ["soil_type": "clay", "depth": "50cm"]
        )
        let created = try repository.create(waypoint)
        let fetched = try repository.fetchById(created.id!)

        XCTAssertEqual(fetched?.customFields["soil_type"], "clay")
        XCTAssertEqual(fetched?.customFields["depth"], "50cm")
    }

    // MARK: - Read Tests

    func testFetchAll() throws {
        try repository.create(Waypoint(projectId: testProjectId, name: "WP1", latitude: 0, longitude: 0))
        try repository.create(Waypoint(projectId: testProjectId, name: "WP2", latitude: 1, longitude: 1))
        try repository.create(Waypoint(projectId: testProjectId, name: "WP3", latitude: 2, longitude: 2))

        let waypoints = try repository.fetchAll(projectId: testProjectId)
        XCTAssertEqual(waypoints.count, 3)
    }

    func testFetchAllWithCategory() throws {
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Site", latitude: 0, longitude: 0, category: .site))
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Feature", latitude: 1, longitude: 1, category: .feature))
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Another Site", latitude: 2, longitude: 2, category: .site))

        let sites = try repository.fetchAll(category: .site)
        XCTAssertEqual(sites.count, 2)
    }

    func testFetchAllWithSearch() throws {
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Archaeological Site", latitude: 0, longitude: 0))
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Control Point", latitude: 1, longitude: 1))
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Site Datum", latitude: 2, longitude: 2))

        let results = try repository.fetchAll(searchTerm: "site")
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Spatial Query Tests

    func testFetchInBoundingBox() throws {
        // Create waypoints in different locations
        try repository.create(Waypoint(
            projectId: testProjectId, name: "NYC", latitude: 40.7128, longitude: -74.0060))
        try repository.create(Waypoint(
            projectId: testProjectId, name: "LA", latitude: 34.0522, longitude: -118.2437))
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Chicago", latitude: 41.8781, longitude: -87.6298))

        // Bounding box around NYC and Chicago
        let results = try repository.fetchInBoundingBox(
            north: 42,
            south: 40,
            east: -73,
            west: -90
        )

        XCTAssertEqual(results.count, 2)
    }

    func testFetchNearby() throws {
        // NYC coordinates
        let nycLat = 40.7128
        let nycLon = -74.0060

        // Create waypoints at various distances
        // ~50m away
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Very Close", latitude: 40.7130, longitude: -74.0065))
        // ~1km away
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Close", latitude: 40.7200, longitude: -74.0100))
        // ~10km away
        try repository.create(Waypoint(
            projectId: testProjectId, name: "Far", latitude: 40.8000, longitude: -74.1000))

        // Fetch within 500m
        let nearby = try repository.fetchNearby(
            latitude: nycLat,
            longitude: nycLon,
            radiusMeters: 500
        )

        XCTAssertEqual(nearby.count, 1)
        XCTAssertEqual(nearby.first?.name, "Very Close")
    }

    // MARK: - Update Tests

    func testUpdateWaypoint() throws {
        var waypoint = try repository.create(Waypoint(
            projectId: testProjectId,
            name: "Original",
            latitude: 0,
            longitude: 0
        ))

        waypoint.name = "Updated"
        waypoint.description = "Added description"
        waypoint.category = .artifact

        let updated = try repository.update(waypoint)
        XCTAssertEqual(updated.name, "Updated")
        XCTAssertEqual(updated.description, "Added description")
        XCTAssertEqual(updated.category, .artifact)
    }

    // MARK: - Delete Tests

    func testDeleteWaypoint() throws {
        let waypoint = try repository.create(Waypoint(
            projectId: testProjectId,
            name: "To Delete",
            latitude: 0,
            longitude: 0
        ))
        guard let id = waypoint.id else {
            XCTFail("Waypoint should have an ID")
            return
        }

        try repository.delete(id: id)

        let fetched = try repository.fetchById(id)
        XCTAssertNil(fetched)
    }

    func testDeleteAllForProject() throws {
        try repository.create(Waypoint(projectId: testProjectId, name: "WP1", latitude: 0, longitude: 0))
        try repository.create(Waypoint(projectId: testProjectId, name: "WP2", latitude: 1, longitude: 1))

        XCTAssertEqual(try repository.countForProject(testProjectId), 2)

        try repository.deleteAll(projectId: testProjectId)

        XCTAssertEqual(try repository.countForProject(testProjectId), 0)
    }

    // MARK: - Count Tests

    func testCountForProject() throws {
        XCTAssertEqual(try repository.countForProject(testProjectId), 0)

        try repository.create(Waypoint(projectId: testProjectId, name: "WP1", latitude: 0, longitude: 0))
        try repository.create(Waypoint(projectId: testProjectId, name: "WP2", latitude: 1, longitude: 1))

        XCTAssertEqual(try repository.countForProject(testProjectId), 2)
    }
}
