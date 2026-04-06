import XCTest
import CoreLocation
@testable import Ayllu

final class GeoCalculatorPolygonTests: XCTestCase {
    // MARK: - Polyline Length

    func testPolylineLengthTwoPoints() {
        let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let losAngeles = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)

        let length = GeoCalculator.polylineLength(coordinates: [sanFrancisco, losAngeles])
        // SF to LA is roughly 559 km
        XCTAssertEqual(length, 559_120, accuracy: 2_000)
    }

    func testPolylineLengthMultiplePoints() {
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1)
        ]

        let length = GeoCalculator.polylineLength(coordinates: coords)
        // Two segments of ~111 km each
        XCTAssertEqual(length, 222_390, accuracy: 1_000)
    }

    func testPolylineLengthSinglePoint() {
        let coords = [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
        XCTAssertEqual(GeoCalculator.polylineLength(coordinates: coords), 0)
    }

    func testPolylineLengthEmpty() {
        XCTAssertEqual(GeoCalculator.polylineLength(coordinates: []), 0)
    }

    // MARK: - Polygon Perimeter

    func testPolygonPerimeter() {
        // 1-degree square at equator (each side ~111 km)
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 0, longitude: 1)
        ]

        let perimeter = GeoCalculator.polygonPerimeter(coordinates: coords)
        // 4 sides of ~111 km = ~444 km
        XCTAssertEqual(perimeter, 443_600, accuracy: 2_000)
    }

    func testPolygonPerimeterTooFewPoints() {
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0)
        ]
        XCTAssertEqual(GeoCalculator.polygonPerimeter(coordinates: coords), 0)
    }

    // MARK: - Polygon Area

    func testPolygonAreaSquareAtEquator() {
        // 1-degree square at equator
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 0, longitude: 1)
        ]

        let area = GeoCalculator.polygonArea(coordinates: coords)
        // 1 degree at equator is ~111 km, so area should be ~12,321 sq km
        let expectedSqKm = 12_321.0
        let areaSqKm = area / 1_000_000
        XCTAssertEqual(areaSqKm, expectedSqKm, accuracy: 200)
    }

    func testPolygonAreaTriangle() {
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 0)
        ]

        let area = GeoCalculator.polygonArea(coordinates: coords)
        XCTAssertGreaterThan(area, 0)
    }

    func testPolygonAreaTooFewPoints() {
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 0)
        ]
        XCTAssertEqual(GeoCalculator.polygonArea(coordinates: coords), 0)
    }

    // MARK: - Formatting

    func testFormatAreaSquareMeters() {
        let result = GeoCalculator.formatArea(500)
        XCTAssertTrue(result.contains("m"))
        XCTAssertTrue(result.contains("500"))
    }

    func testFormatAreaHectares() {
        let result = GeoCalculator.formatArea(50_000)
        XCTAssertTrue(result.contains("ha"))
    }

    func testFormatAreaSquareKilometers() {
        let result = GeoCalculator.formatArea(5_000_000)
        XCTAssertTrue(result.contains("km"))
    }

    func testFormatLengthMeters() {
        let result = GeoCalculator.formatLength(500)
        XCTAssertTrue(result.contains("m"))
    }

    func testFormatLengthKilometers() {
        let result = GeoCalculator.formatLength(5_000)
        XCTAssertTrue(result.contains("km"))
    }
}
