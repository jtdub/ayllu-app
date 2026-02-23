import XCTest
@testable import Ayllu
import CoreLocation

final class CoordinateFormatterTests: XCTestCase {
    // MARK: - Decimal Format Tests

    func testDecimalFormat() {
        let result = CoordinateFormatter.formatDecimal(latitude: 37.7749, longitude: -122.4194)
        XCTAssertEqual(result, "37.774900, -122.419400")
    }

    func testDecimalFormatNegativeLatitude() {
        let result = CoordinateFormatter.formatDecimal(latitude: -33.8688, longitude: 151.2093)
        XCTAssertEqual(result, "-33.868800, 151.209300")
    }

    func testDecimalFormatEquator() {
        let result = CoordinateFormatter.formatDecimal(latitude: 0, longitude: 0)
        XCTAssertEqual(result, "0.000000, 0.000000")
    }

    // MARK: - DMS Format Tests

    func testDMSFormat() {
        let result = CoordinateFormatter.formatDMS(latitude: 37.7749, longitude: -122.4194)
        XCTAssertTrue(result.contains("37°"))
        XCTAssertTrue(result.contains("N"))
        XCTAssertTrue(result.contains("122°"))
        XCTAssertTrue(result.contains("W"))
    }

    func testDMSFormatSouthernHemisphere() {
        let result = CoordinateFormatter.formatDMS(latitude: -33.8688, longitude: 151.2093)
        XCTAssertTrue(result.contains("S"))
        XCTAssertTrue(result.contains("E"))
    }

    func testDMSComponentLatitude() {
        let result = CoordinateFormatter.formatDMSLatitude(45.5)
        XCTAssertEqual(result, "45° 30' 0.00\" N")
    }

    func testDMSComponentLongitude() {
        let result = CoordinateFormatter.formatDMSLongitude(-90.25)
        XCTAssertEqual(result, "90° 15' 0.00\" W")
    }

    // MARK: - UTM Format Tests

    func testUTMFormat() {
        let result = CoordinateFormatter.formatUTM(latitude: 37.7749, longitude: -122.4194)
        XCTAssertTrue(result.contains("N") || result.contains("S"))
        // Should contain zone number, easting, northing
        let components = result.split(separator: " ")
        XCTAssertEqual(components.count, 3)
    }

    func testUTMZone() {
        let zone = CoordinateFormatter.utmZone(latitude: 37.7749, longitude: -122.4194)
        XCTAssertNotNil(zone)
        XCTAssertTrue(zone!.contains("N"))  // Northern hemisphere
    }

    func testUTMPolarRegionFallback() {
        // UTM doesn't cover polar regions
        let result = CoordinateFormatter.formatUTM(latitude: 85, longitude: 0)
        // Should fall back to decimal
        XCTAssertTrue(result.contains("85"))
    }

    // MARK: - Format Enum Tests

    func testFormatWithEnum() {
        let decimal = CoordinateFormatter.format(latitude: 45, longitude: -90, format: .decimal)
        let dms = CoordinateFormatter.format(latitude: 45, longitude: -90, format: .dms)
        let utm = CoordinateFormatter.format(latitude: 45, longitude: -90, format: .utm)

        XCTAssertTrue(decimal.contains("45"))
        XCTAssertTrue(dms.contains("°"))
        XCTAssertFalse(utm.isEmpty)
    }

    func testFormatWithCoordinate() {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let result = CoordinateFormatter.format(coordinate: coordinate, format: .decimal)
        XCTAssertEqual(result, "37.774900, -122.419400")
    }

    func testFormatWithLocation() {
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let result = CoordinateFormatter.format(location: location, format: .decimal)
        XCTAssertEqual(result, "37.774900, -122.419400")
    }

    // MARK: - Parsing Tests

    func testParseDecimal() {
        let result = CoordinateFormatter.parseDecimal("37.7749, -122.4194")
        XCTAssertNotNil(result)
        guard let coordinate = result else { return }
        XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.0001)
    }

    func testParseDecimalInvalid() {
        let result = CoordinateFormatter.parseDecimal("not a coordinate")
        XCTAssertNil(result)
    }

    func testParseDecimalOutOfRange() {
        let result = CoordinateFormatter.parseDecimal("91, 0")  // Latitude out of range
        XCTAssertNil(result)
    }

    func testParseDMS() {
        let result = CoordinateFormatter.parseDMS("37° 46' 29.64\" N, 122° 25' 9.84\" W")
        XCTAssertNotNil(result)
        guard let coordinate = result else { return }
        XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.001)
        XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.001)
    }

    func testParseDMSInvalid() {
        let result = CoordinateFormatter.parseDMS("not valid DMS")
        XCTAssertNil(result)
    }

    // MARK: - Validation Tests

    func testValidLatitude() {
        XCTAssertTrue(CoordinateFormatter.isValidLatitude(0))
        XCTAssertTrue(CoordinateFormatter.isValidLatitude(90))
        XCTAssertTrue(CoordinateFormatter.isValidLatitude(-90))
        XCTAssertTrue(CoordinateFormatter.isValidLatitude(45.5))

        XCTAssertFalse(CoordinateFormatter.isValidLatitude(91))
        XCTAssertFalse(CoordinateFormatter.isValidLatitude(-91))
    }

    func testValidLongitude() {
        XCTAssertTrue(CoordinateFormatter.isValidLongitude(0))
        XCTAssertTrue(CoordinateFormatter.isValidLongitude(180))
        XCTAssertTrue(CoordinateFormatter.isValidLongitude(-180))
        XCTAssertTrue(CoordinateFormatter.isValidLongitude(-122.4194))

        XCTAssertFalse(CoordinateFormatter.isValidLongitude(181))
        XCTAssertFalse(CoordinateFormatter.isValidLongitude(-181))
    }

    func testValidCoordinate() {
        XCTAssertTrue(CoordinateFormatter.isValidCoordinate(latitude: 0, longitude: 0))
        XCTAssertTrue(CoordinateFormatter.isValidCoordinate(latitude: 90, longitude: 180))
        XCTAssertTrue(CoordinateFormatter.isValidCoordinate(latitude: -90, longitude: -180))

        XCTAssertFalse(CoordinateFormatter.isValidCoordinate(latitude: 91, longitude: 0))
        XCTAssertFalse(CoordinateFormatter.isValidCoordinate(latitude: 0, longitude: 181))
    }

    // MARK: - Altitude Formatting Tests

    func testFormatAltitudeMeters() {
        let result = CoordinateFormatter.formatAltitude(1_500, unit: .meters)
        XCTAssertEqual(result, "1500.0 m")
    }

    func testFormatAltitudeFeet() {
        let result = CoordinateFormatter.formatAltitude(100, unit: .feet)
        XCTAssertEqual(result, "328.1 ft")
    }

    // MARK: - Distance Formatting Tests

    func testFormatDistanceMetersShort() {
        let result = CoordinateFormatter.formatDistance(500, unit: .meters)
        XCTAssertEqual(result, "500.0 m")
    }

    func testFormatDistanceKilometers() {
        let result = CoordinateFormatter.formatDistance(2_500, unit: .meters)
        XCTAssertEqual(result, "2.50 km")
    }

    func testFormatDistanceFeetShort() {
        let result = CoordinateFormatter.formatDistance(100, unit: .feet)
        XCTAssertEqual(result, "328.1 ft")
    }

    func testFormatDistanceMiles() {
        let result = CoordinateFormatter.formatDistance(5_000, unit: .feet)
        XCTAssertTrue(result.contains("mi"))
    }

    // MARK: - Accuracy Formatting Tests

    func testFormatAccuracyMeters() {
        let result = CoordinateFormatter.formatAccuracy(5.5, unit: .meters)
        XCTAssertEqual(result, "±5.5 m")
    }

    func testFormatAccuracyFeet() {
        let result = CoordinateFormatter.formatAccuracy(3, unit: .feet)
        XCTAssertEqual(result, "±9.8 ft")
    }

    // MARK: - Edge Cases

    func testInternationalDateLine() {
        // Test coordinates near the International Date Line
        let west = CoordinateFormatter.format(latitude: 0, longitude: 179.9, format: .decimal)
        let east = CoordinateFormatter.format(latitude: 0, longitude: -179.9, format: .decimal)

        XCTAssertTrue(west.contains("179.9"))
        XCTAssertTrue(east.contains("-179.9"))
    }

    func testPrimeMeridian() {
        let result = CoordinateFormatter.formatDMS(latitude: 51.4769, longitude: 0)
        XCTAssertTrue(result.contains("E") || result.contains("0°"))
    }

    func testEquator() {
        let result = CoordinateFormatter.formatDMS(latitude: 0, longitude: 45)
        XCTAssertTrue(result.contains("N") || result.contains("0°"))
    }
}
