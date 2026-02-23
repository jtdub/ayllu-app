import XCTest
@testable import Ayllu
import CoreLocation

final class MapRegionModelTests: XCTestCase {
    func testCenterCoordinate() {
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

    func testContainsCoordinate() {
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

    func testFormattedSize() {
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

    func testDownloadStatusProperties() {
        XCTAssertEqual(DownloadStatus.complete.displayName, "Complete")
        XCTAssertEqual(DownloadStatus.downloading.displayName, "Downloading")
        XCTAssertEqual(DownloadStatus.pending.displayName, "Pending")
        XCTAssertEqual(DownloadStatus.paused.displayName, "Paused")
        XCTAssertEqual(DownloadStatus.failed.displayName, "Failed")

        XCTAssertEqual(DownloadStatus.complete.iconName, "checkmark.circle.fill")
        XCTAssertEqual(DownloadStatus.downloading.iconName, "arrow.down.circle")
    }
}
