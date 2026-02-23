import XCTest
@testable import Ayllu
import CoreLocation

final class GeoCalculatorTests: XCTestCase {
    // MARK: - Distance Tests

    func testDistanceSamePoint() {
        let point = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let distance = GeoCalculator.distance(from: point, to: point)
        XCTAssertEqual(distance, 0, accuracy: 0.001)
    }

    func testDistanceKnownPoints() {
        // San Francisco to Los Angeles: approximately 559 km
        let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let losAngeles = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)

        let distance = GeoCalculator.distance(from: sanFrancisco, to: losAngeles)
        XCTAssertEqual(distance, 559_120, accuracy: 1_000) // Within 1km
    }

    func testDistanceShortRange() {
        // Two points 100 meters apart
        let point1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let point2 = CLLocationCoordinate2D(latitude: 37.7758, longitude: -122.4194)

        let distance = GeoCalculator.distance(from: point1, to: point2)
        XCTAssertEqual(distance, 100, accuracy: 10) // Within 10m
    }

    func testDistanceWaypoints() {
        let wp1 = Waypoint(projectId: 1, name: "A", latitude: 37.7749, longitude: -122.4194)
        let wp2 = Waypoint(projectId: 1, name: "B", latitude: 37.7849, longitude: -122.4094)

        let distance = GeoCalculator.distance(from: wp1, to: wp2)
        XCTAssertGreaterThan(distance, 0)
    }

    // MARK: - Bearing Tests

    func testBearingNorth() {
        let from = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let to = CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0)

        let bearing = GeoCalculator.bearing(from: from, to: to)
        XCTAssertEqual(bearing, 0, accuracy: 1) // Due north
    }

    func testBearingSouth() {
        let from = CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0)
        let to = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)

        let bearing = GeoCalculator.bearing(from: from, to: to)
        XCTAssertEqual(bearing, 180, accuracy: 1) // Due south
    }

    func testBearingEast() {
        let from = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let to = CLLocationCoordinate2D(latitude: 37.0, longitude: -121.0)

        let bearing = GeoCalculator.bearing(from: from, to: to)
        XCTAssertEqual(bearing, 90, accuracy: 1) // Due east
    }

    func testBearingWest() {
        let from = CLLocationCoordinate2D(latitude: 37.0, longitude: -121.0)
        let to = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)

        let bearing = GeoCalculator.bearing(from: from, to: to)
        XCTAssertEqual(bearing, 270, accuracy: 1) // Due west
    }

    func testBearingRange() {
        // Bearing should always be 0-360
        let from = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let to = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)

        let bearing = GeoCalculator.bearing(from: from, to: to)
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
    }

    // MARK: - Magnetic Declination Tests

    func testMagneticBearingEastDeclination() {
        // East declination means magnetic north is east of true north
        let trueBearing = 90.0
        let declination = 10.0 // 10° east

        let magnetic = GeoCalculator.magneticBearing(trueBearing: trueBearing, declination: declination)
        XCTAssertEqual(magnetic, 80, accuracy: 0.01)
    }

    func testMagneticBearingWestDeclination() {
        let trueBearing = 90.0
        let declination = -10.0 // 10° west

        let magnetic = GeoCalculator.magneticBearing(trueBearing: trueBearing, declination: declination)
        XCTAssertEqual(magnetic, 100, accuracy: 0.01)
    }

    func testTrueBearingConversion() {
        let magneticBearing = 80.0
        let declination = 10.0

        let trueBearing = GeoCalculator.trueBearing(magneticBearing: magneticBearing, declination: declination)
        XCTAssertEqual(trueBearing, 90, accuracy: 0.01)
    }

    func testMagneticBearingWrapAround() {
        let trueBearing = 5.0
        let declination = 10.0

        let magnetic = GeoCalculator.magneticBearing(trueBearing: trueBearing, declination: declination)
        XCTAssertEqual(magnetic, 355, accuracy: 0.01)
    }

    // MARK: - Destination Point Tests

    func testDestinationPointNorth() {
        let from = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let distance = 1_000.0 // 1 km
        let bearing = 0.0 // North

        let dest = GeoCalculator.destination(from: from, bearing: bearing, distance: distance)

        XCTAssertGreaterThan(dest.latitude, from.latitude)
        XCTAssertEqual(dest.longitude, from.longitude, accuracy: 0.0001)
    }

    func testDestinationPointEast() {
        let from = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let distance = 1_000.0
        let bearing = 90.0

        let dest = GeoCalculator.destination(from: from, bearing: bearing, distance: distance)

        XCTAssertEqual(dest.latitude, from.latitude, accuracy: 0.001)
        XCTAssertGreaterThan(dest.longitude, from.longitude)
    }

    func testDestinationPointRoundTrip() {
        let from = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let distance = 5_000.0
        let bearing = 45.0

        let dest = GeoCalculator.destination(from: from, bearing: bearing, distance: distance)
        let calculatedDistance = GeoCalculator.distance(from: from, to: dest)

        XCTAssertEqual(calculatedDistance, distance, accuracy: 1) // Within 1m
    }

    // MARK: - Cardinal Direction Tests

    func testCardinalDirectionNorth() {
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 0), "N")
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 360), "N")
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 5), "N")
    }

    func testCardinalDirectionEast() {
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 90), "E")
    }

    func testCardinalDirectionSouth() {
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 180), "S")
    }

    func testCardinalDirectionWest() {
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 270), "W")
    }

    func testCardinalDirectionIntercardinals() {
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 45), "NE")
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 135), "SE")
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 225), "SW")
        XCTAssertEqual(GeoCalculator.cardinalDirection(bearing: 315), "NW")
    }

    // MARK: - Formatting Tests

    func testFormatBearing() {
        let formatted = GeoCalculator.formatBearing(45)
        XCTAssertTrue(formatted.contains("45"))
        XCTAssertTrue(formatted.contains("NE"))
    }

    func testFormatBearingDegrees() {
        XCTAssertEqual(GeoCalculator.formatBearingDegrees(90), "90°")
        XCTAssertEqual(GeoCalculator.formatBearingDegrees(270), "270°")
    }
}
