import XCTest
@testable import Ayllu
import GRDB

final class PhotoRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var repository: PhotoRepository!
    var projectId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        repository = PhotoRepository(dbPool: database.dbPool)

        // Create a project for photos
        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        let project = try projectRepo.create(Project(name: "Test Project"))
        projectId = project.id
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
        projectId = nil
    }

    // MARK: - Create Tests

    func testCreatePhoto() throws {
        let photo = Photo(
            projectId: projectId,
            filePath: "/photos/IMG_001.jpg",
            caption: "Test photo"
        )
        let created = try repository.create(photo)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.filePath, "/photos/IMG_001.jpg")
        XCTAssertEqual(created.caption, "Test photo")
        XCTAssertEqual(created.projectId, projectId)
    }

    func testCreateGeotaggedPhoto() throws {
        let photo = Photo(
            projectId: projectId,
            filePath: "/photos/IMG_002.jpg",
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 10.5,
            heading: 45.0
        )
        let created = try repository.create(photo)

        XCTAssertTrue(created.hasLocation)
        XCTAssertNotNil(created.coordinate)
        guard let lat = created.latitude, let lon = created.longitude else {
            XCTFail("Latitude and longitude should exist")
            return
        }
        XCTAssertEqual(lat, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(lon, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(created.altitude, 10.5)
        XCTAssertEqual(created.heading, 45.0)
    }

    // MARK: - Read Tests

    func testFetchAll() throws {
        try repository.create(Photo(projectId: projectId, filePath: "/p1.jpg"))
        try repository.create(Photo(projectId: projectId, filePath: "/p2.jpg"))
        try repository.create(Photo(projectId: projectId, filePath: "/p3.jpg"))

        let photos = try repository.fetchAll()
        XCTAssertEqual(photos.count, 3)
    }

    func testFetchAllByProject() throws {
        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        let otherProject = try projectRepo.create(Project(name: "Other Project"))
        guard let otherProjectId = otherProject.id else {
            XCTFail("Project should have ID")
            return
        }

        try repository.create(Photo(projectId: projectId, filePath: "/p1.jpg"))
        try repository.create(Photo(projectId: projectId, filePath: "/p2.jpg"))
        try repository.create(Photo(projectId: otherProjectId, filePath: "/p3.jpg"))

        let projectPhotos = try repository.fetchAll(projectId: projectId)
        XCTAssertEqual(projectPhotos.count, 2)
    }

    func testFetchById() throws {
        let created = try repository.create(Photo(projectId: projectId, filePath: "/test.jpg"))
        guard let id = created.id else {
            XCTFail("Photo should have an ID")
            return
        }

        let fetched = try repository.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.filePath, "/test.jpg")
    }

    func testFetchInBoundingBox() throws {
        try repository.create(Photo(projectId: projectId, filePath: "/sf.jpg", latitude: 37.7749, longitude: -122.4194))
        try repository.create(Photo(projectId: projectId, filePath: "/ny.jpg", latitude: 40.7128, longitude: -74.0060))
        try repository.create(Photo(projectId: projectId, filePath: "/la.jpg", latitude: 34.0522, longitude: -118.2437))

        let sfPhotos = try repository.fetchInBoundingBox(north: 38.0, south: 37.0, east: -122.0, west: -123.0)

        XCTAssertEqual(sfPhotos.count, 1)
        XCTAssertEqual(sfPhotos.first?.filePath, "/sf.jpg")
    }

    func testFetchByWaypoint() throws {
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        let waypoint = try waypointRepo.create(Waypoint(projectId: projectId, name: "WP1", latitude: 0, longitude: 0))
        guard let waypointId = waypoint.id else {
            XCTFail("Waypoint should have ID")
            return
        }

        try repository.create(Photo(projectId: projectId, filePath: "/unlinked.jpg"))
        try repository.create(Photo(projectId: projectId, waypointId: waypointId, filePath: "/linked.jpg"))

        let waypointPhotos = try repository.fetchAll(waypointId: waypointId)
        XCTAssertEqual(waypointPhotos.count, 1)
        XCTAssertEqual(waypointPhotos.first?.filePath, "/linked.jpg")
    }

    // MARK: - Update Tests

    func testUpdatePhoto() throws {
        var photo = try repository.create(Photo(projectId: projectId, filePath: "/test.jpg"))
        photo.caption = "Updated caption"
        let updated = try repository.update(photo)
        XCTAssertEqual(updated.caption, "Updated caption")
    }

    func testLinkToWaypoint() throws {
        let photo = try repository.create(Photo(projectId: projectId, filePath: "/test.jpg"))
        guard let photoId = photo.id else {
            XCTFail("Photo should have ID")
            return
        }
        XCTAssertNil(photo.waypointId)

        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        let waypoint = try waypointRepo.create(Waypoint(projectId: projectId, name: "WP1", latitude: 0, longitude: 0))

        try repository.linkToWaypoint(photoId: photoId, waypointId: waypoint.id)

        let fetched = try repository.fetchById(photoId)
        XCTAssertEqual(fetched?.waypointId, waypoint.id)
    }

    func testUpdateCaption() throws {
        let photo = try repository.create(Photo(projectId: projectId, filePath: "/test.jpg"))
        guard let photoId = photo.id else {
            XCTFail("Photo should have ID")
            return
        }
        try repository.updateCaption(photoId: photoId, caption: "New caption")
        let fetched = try repository.fetchById(photoId)
        XCTAssertEqual(fetched?.caption, "New caption")
    }

    // MARK: - Delete Tests

    func testDeletePhoto() throws {
        let photo = try repository.create(Photo(projectId: projectId, filePath: "/delete.jpg"))
        guard let id = photo.id else {
            XCTFail("Photo should have ID")
            return
        }
        try repository.delete(id: id)
        let fetched = try repository.fetchById(id)
        XCTAssertNil(fetched)
    }

    func testDeleteAllForProject() throws {
        try repository.create(Photo(projectId: projectId, filePath: "/p1.jpg"))
        try repository.create(Photo(projectId: projectId, filePath: "/p2.jpg"))
        XCTAssertEqual(try repository.countForProject(projectId), 2)
        try repository.deleteAll(projectId: projectId)
        XCTAssertEqual(try repository.countForProject(projectId), 0)
    }

    // MARK: - Count Tests

    func testCount() throws {
        XCTAssertEqual(try repository.count(), 0)
        try repository.create(Photo(projectId: projectId, filePath: "/p1.jpg"))
        try repository.create(Photo(projectId: projectId, filePath: "/p2.jpg"))
        XCTAssertEqual(try repository.count(), 2)
    }

    // MARK: - URL Tests

    func testFileURL() throws {
        let photo = try repository.create(Photo(
            projectId: projectId,
            filePath: "/photos/test.jpg",
            thumbnailPath: "/photos/thumb_test.jpg"
        ))
        XCTAssertNotNil(photo.fileURL)
        XCTAssertEqual(photo.fileURL?.lastPathComponent, "test.jpg")
        XCTAssertNotNil(photo.thumbnailURL)
        XCTAssertEqual(photo.thumbnailURL?.lastPathComponent, "thumb_test.jpg")
    }
}

// MARK: - Spatial and Search Tests

extension PhotoRepositoryTests {
    func testFetchNearby() throws {
        try repository.create(Photo(projectId: projectId, filePath: "/sf.jpg", latitude: 37.77, longitude: -122.42))
        try repository.create(Photo(projectId: projectId, filePath: "/oak.jpg", latitude: 37.80, longitude: -122.27))
        try repository.create(Photo(projectId: projectId, filePath: "/la.jpg", latitude: 34.05, longitude: -118.24))

        let nearbyPhotos = try repository.fetchNearby(latitude: 37.7749, longitude: -122.4194, radiusMeters: 20_000)

        XCTAssertEqual(nearbyPhotos.count, 2)
        XCTAssertEqual(nearbyPhotos.first?.filePath, "/sf.jpg")
    }

    func testSearchByCaption() throws {
        try repository.create(Photo(projectId: projectId, filePath: "/artifact1.jpg", caption: "Ceramic fragment"))
        try repository.create(Photo(projectId: projectId, filePath: "/artifact2.jpg", caption: "Stone tool fragment"))
        try repository.create(Photo(projectId: projectId, filePath: "/landscape.jpg", caption: "Site overview"))

        let fragmentPhotos = try repository.search(term: "fragment")
        XCTAssertEqual(fragmentPhotos.count, 2)

        let ceramicPhotos = try repository.search(term: "ceramic")
        XCTAssertEqual(ceramicPhotos.count, 1)
        XCTAssertEqual(ceramicPhotos.first?.filePath, "/artifact1.jpg")
    }
}

// MARK: - Delete with Cleanup Tests

extension PhotoRepositoryTests {
    func testDeleteWithCleanup() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let photoPath = tempDir.appendingPathComponent("test_photo_\(UUID()).jpg").path
        let thumbPath = tempDir.appendingPathComponent("test_thumb_\(UUID()).jpg").path

        FileManager.default.createFile(atPath: photoPath, contents: Data())
        FileManager.default.createFile(atPath: thumbPath, contents: Data())

        XCTAssertTrue(FileManager.default.fileExists(atPath: photoPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbPath))

        let photo = try repository.create(Photo(projectId: projectId, filePath: photoPath, thumbnailPath: thumbPath))
        guard let id = photo.id else {
            XCTFail("Photo should have ID")
            return
        }

        let deletedPaths = try repository.deleteWithCleanup(id: id)

        XCTAssertNil(try repository.fetchById(id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbPath))
        XCTAssertEqual(deletedPaths.count, 2)
    }

    func testDeleteAllWithCleanup() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let photo1Path = tempDir.appendingPathComponent("photo1_\(UUID()).jpg").path
        let photo2Path = tempDir.appendingPathComponent("photo2_\(UUID()).jpg").path

        FileManager.default.createFile(atPath: photo1Path, contents: Data())
        FileManager.default.createFile(atPath: photo2Path, contents: Data())

        try repository.create(Photo(projectId: projectId, filePath: photo1Path))
        try repository.create(Photo(projectId: projectId, filePath: photo2Path))

        XCTAssertEqual(try repository.countForProject(projectId), 2)

        let deletedPaths = try repository.deleteAllWithCleanup(projectId: projectId)

        XCTAssertEqual(try repository.countForProject(projectId), 0)
        XCTAssertEqual(deletedPaths.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photo1Path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: photo2Path))
    }
}

// MARK: - Additional Count Tests

extension PhotoRepositoryTests {
    func testCountForWaypoint() throws {
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        let waypoint = try waypointRepo.create(Waypoint(projectId: projectId, name: "WP1", latitude: 0, longitude: 0))

        try repository.create(Photo(projectId: projectId, filePath: "/unlinked.jpg"))
        try repository.create(Photo(projectId: projectId, waypointId: waypoint.id, filePath: "/linked1.jpg"))
        try repository.create(Photo(projectId: projectId, waypointId: waypoint.id, filePath: "/linked2.jpg"))

        XCTAssertEqual(try repository.countForWaypoint(waypoint.id!), 2)
    }

    func testCountGeotagged() throws {
        try repository.create(Photo(projectId: projectId, filePath: "/geo.jpg", latitude: 37.77, longitude: -122.42))
        try repository.create(Photo(projectId: projectId, filePath: "/not_geotagged.jpg"))

        XCTAssertEqual(try repository.countGeotagged(), 1)
        XCTAssertEqual(try repository.countGeotagged(projectId: projectId), 1)
    }
}
