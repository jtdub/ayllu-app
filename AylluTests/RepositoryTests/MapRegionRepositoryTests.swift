import XCTest
@testable import Ayllu
import GRDB

final class MapRegionRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var repository: MapRegionRepository!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        repository = MapRegionRepository(dbPool: database.dbPool)
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
    }

    // MARK: - Create Tests

    func testCreateRegion() throws {
        let region = MapRegion(
            name: "San Francisco Bay",
            description: "Bay Area coverage",
            northLatitude: 38.0,
            southLatitude: 37.0,
            eastLongitude: -121.5,
            westLongitude: -123.0,
            minZoom: 10,
            maxZoom: 16
        )
        let created = try repository.create(region)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "San Francisco Bay")
        XCTAssertEqual(created.status, .pending)
        XCTAssertEqual(created.minZoom, 10)
        XCTAssertEqual(created.maxZoom, 16)
    }

    // MARK: - Read Tests

    func testFetchAll() throws {
        try repository.create(MapRegion(
            name: "R1",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))
        try repository.create(MapRegion(
            name: "R2",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))

        let regions = try repository.fetchAll()
        XCTAssertEqual(regions.count, 2)
    }

    func testFetchAllByStatus() throws {
        var region1 = try repository.create(MapRegion(
            name: "Downloading",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .downloading
        ))
        var region2 = try repository.create(MapRegion(
            name: "Complete",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .complete
        ))

        let downloading = try repository.fetchAll(status: .downloading)
        XCTAssertEqual(downloading.count, 1)
        XCTAssertEqual(downloading.first?.name, "Downloading")

        let complete = try repository.fetchAll(status: .complete)
        XCTAssertEqual(complete.count, 1)
        XCTAssertEqual(complete.first?.name, "Complete")
    }

    func testFetchById() throws {
        let created = try repository.create(MapRegion(
            name: "Test",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))
        guard let id = created.id else {
            XCTFail("Region should have ID")
            return
        }

        let fetched = try repository.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Test")
    }

    func testFetchContaining() throws {
        // Create a region covering San Francisco
        try repository.create(MapRegion(
            name: "SF Area",
            northLatitude: 38.0,
            southLatitude: 37.0,
            eastLongitude: -121.5,
            westLongitude: -123.0,
            status: .complete
        ))

        // Create a region covering New York (won't match)
        try repository.create(MapRegion(
            name: "NY Area",
            northLatitude: 41.0,
            southLatitude: 40.0,
            eastLongitude: -73.0,
            westLongitude: -75.0,
            status: .complete
        ))

        // Point in SF
        let containingSF = try repository.fetchContaining(
            latitude: 37.7749,
            longitude: -122.4194
        )
        XCTAssertEqual(containingSF.count, 1)
        XCTAssertEqual(containingSF.first?.name, "SF Area")

        // Point outside both regions
        let containingNone = try repository.fetchContaining(
            latitude: 35.0,
            longitude: -100.0
        )
        XCTAssertEqual(containingNone.count, 0)
    }

    func testFetchCompleted() throws {
        try repository.create(MapRegion(
            name: "Complete1",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .complete
        ))
        try repository.create(MapRegion(
            name: "Downloading",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .downloading
        ))

        let completed = try repository.fetchCompleted()
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed.first?.name, "Complete1")
    }

    func testFetchDownloading() throws {
        try repository.create(MapRegion(
            name: "D1",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .downloading
        ))

        let downloading = try repository.fetchDownloading()
        XCTAssertEqual(downloading.count, 1)
    }

    // MARK: - Update Tests

    func testUpdateRegion() throws {
        var region = try repository.create(MapRegion(
            name: "Original",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))
        region.name = "Updated"
        region.description = "New description"

        let updated = try repository.update(region)
        XCTAssertEqual(updated.name, "Updated")
        XCTAssertEqual(updated.description, "New description")
    }

    func testUpdateProgress() throws {
        let region = try repository.create(MapRegion(
            name: "Test",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))
        guard let id = region.id else {
            XCTFail("Region should have ID")
            return
        }

        try repository.updateProgress(regionId: id, downloadedBytes: 5_000_000, totalBytes: 10_000_000)

        let fetched = try repository.fetchById(id)
        XCTAssertEqual(fetched?.downloadedBytes, 5_000_000)
        XCTAssertEqual(fetched?.totalBytes, 10_000_000)
        XCTAssertEqual(fetched?.downloadProgress ?? 0, 0.5, accuracy: 0.01)
    }

    func testUpdateStatus() throws {
        let region = try repository.create(MapRegion(
            name: "Test",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))
        guard let id = region.id else {
            XCTFail("Region should have ID")
            return
        }

        try repository.updateStatus(regionId: id, status: .downloading)
        var fetched = try repository.fetchById(id)
        XCTAssertEqual(fetched?.status, .downloading)

        try repository.updateStatus(regionId: id, status: .failed, error: "Network error")
        fetched = try repository.fetchById(id)
        XCTAssertEqual(fetched?.status, .failed)
        XCTAssertEqual(fetched?.downloadError, "Network error")
    }

    func testMarkComplete() throws {
        let region = try repository.create(MapRegion(
            name: "Test",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .downloading
        ))
        guard let id = region.id else {
            XCTFail("Region should have ID")
            return
        }

        try repository.markComplete(regionId: id, tileCount: 1_000, totalBytes: 15_000_000)

        let fetched = try repository.fetchById(id)
        XCTAssertEqual(fetched?.status, .complete)
        XCTAssertEqual(fetched?.tileCount, 1_000)
        XCTAssertEqual(fetched?.downloadedBytes, 15_000_000)
        XCTAssertEqual(fetched?.totalBytes, 15_000_000)
    }

    // MARK: - Delete Tests

    func testDeleteRegion() throws {
        let region = try repository.create(MapRegion(
            name: "Delete",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))
        guard let id = region.id else {
            XCTFail("Region should have ID")
            return
        }

        try repository.delete(id: id)

        let fetched = try repository.fetchById(id)
        XCTAssertNil(fetched)
    }

    // MARK: - Statistics Tests

    func testTotalStorageUsed() throws {
        try repository.create(MapRegion(
            name: "R1",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            downloadedBytes: 10_000_000,
            status: .complete
        ))
        try repository.create(MapRegion(
            name: "R2",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            downloadedBytes: 5_000_000,
            status: .complete
        ))
        // This one shouldn't count (not complete)
        try repository.create(MapRegion(
            name: "R3",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            downloadedBytes: 3_000_000,
            status: .downloading
        ))

        let total = try repository.totalStorageUsed()
        XCTAssertEqual(total, 15_000_000)  // Only complete regions count
    }

    func testFormattedStorageUsed() throws {
        try repository.create(MapRegion(
            name: "R1",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            downloadedBytes: 10_000_000,
            status: .complete
        ))

        let formatted = try repository.formattedStorageUsed()
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("10"))
    }

    // MARK: - Count Tests

    func testCount() throws {
        XCTAssertEqual(try repository.count(), 0)

        try repository.create(MapRegion(
            name: "R1",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        ))

        XCTAssertEqual(try repository.count(), 1)
    }

    func testCountCompleted() throws {
        try repository.create(MapRegion(
            name: "Complete",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .complete
        ))
        try repository.create(MapRegion(
            name: "Pending",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0,
            status: .pending
        ))

        XCTAssertEqual(try repository.countCompleted(), 1)
    }

    // MARK: - Model Property Tests

    func testCenterCoordinate() throws {
        let region = MapRegion(
            name: "Test",
            northLatitude: 40.0,
            southLatitude: 38.0,
            eastLongitude: -120.0,
            westLongitude: -124.0
        )

        let center = region.centerCoordinate
        XCTAssertEqual(center.latitude, 39.0, accuracy: 0.001)
        XCTAssertEqual(center.longitude, -122.0, accuracy: 0.001)
    }

    func testContainsCoordinate() throws {
        let region = MapRegion(
            name: "Test",
            northLatitude: 38.0,
            southLatitude: 37.0,
            eastLongitude: -121.5,
            westLongitude: -123.0
        )

        // Inside
        XCTAssertTrue(region.contains(
            coordinate: .init(latitude: 37.5, longitude: -122.0)
        ))

        // Outside (north)
        XCTAssertFalse(region.contains(
            coordinate: .init(latitude: 39.0, longitude: -122.0)
        ))

        // Outside (east)
        XCTAssertFalse(region.contains(
            coordinate: .init(latitude: 37.5, longitude: -120.0)
        ))
    }

    func testFormattedSize() throws {
        var region = MapRegion(
            name: "Test",
            northLatitude: 1, southLatitude: 0,
            eastLongitude: 1, westLongitude: 0
        )

        region.downloadedBytes = nil
        XCTAssertEqual(region.formattedSize, "—")

        region.downloadedBytes = 1_500_000
        XCTAssertTrue(region.formattedSize.contains("MB") || region.formattedSize.contains("1"))
    }

    func testDownloadStatusProperties() throws {
        XCTAssertEqual(DownloadStatus.complete.displayName, "Complete")
        XCTAssertEqual(DownloadStatus.downloading.displayName, "Downloading")
        XCTAssertEqual(DownloadStatus.pending.displayName, "Pending")
        XCTAssertEqual(DownloadStatus.paused.displayName, "Paused")
        XCTAssertEqual(DownloadStatus.failed.displayName, "Failed")

        XCTAssertEqual(DownloadStatus.complete.iconName, "checkmark.circle.fill")
        XCTAssertEqual(DownloadStatus.downloading.iconName, "arrow.down.circle")
    }
}
