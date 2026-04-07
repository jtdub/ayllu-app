import XCTest
@testable import Ayllu

final class GeoJSONImportServiceTests: XCTestCase {
    func testParseFeatureCollectionWithPoint() throws {
        let json = Data("""
        {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [-122.4194, 37.7749, 10.5]},
            "properties": {"name": "SF", "description": "San Francisco"}
          }]
        }
        """.utf8)

        let items = try GeoJSONImportService.parse(data: json)
        XCTAssertEqual(items.count, 1)

        guard case .waypoint(let wp) = items[0] else {
            XCTFail("Expected waypoint")
            return
        }
        XCTAssertEqual(wp.name, "SF")
        XCTAssertEqual(wp.description, "San Francisco")
        XCTAssertEqual(wp.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(wp.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(wp.altitude, 10.5, accuracy: 0.1)
    }

    func testParsePolygon() throws {
        let json = Data("""
        {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {
              "type": "Polygon",
              "coordinates": [
                [[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0], [-121.0, 37.0], [-122.0, 37.0]]
              ]
            },
            "properties": {"name": "Test Area"}
          }]
        }
        """.utf8)

        let items = try GeoJSONImportService.parse(data: json)
        XCTAssertEqual(items.count, 1)

        guard case .geometry(let geo) = items[0] else {
            XCTFail("Expected geometry")
            return
        }
        XCTAssertEqual(geo.name, "Test Area")
        XCTAssertEqual(geo.geometryType, .polygon)
        XCTAssertEqual(geo.coordinates.count, 4)
    }

    func testParseLineString() throws {
        let json = Data("""
        {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [[-122.0, 37.0], [-121.5, 37.5], [-121.0, 38.0]]
            },
            "properties": {"name": "Trail"}
          }]
        }
        """.utf8)

        let items = try GeoJSONImportService.parse(data: json)
        guard case .geometry(let geo) = items[0] else {
            XCTFail("Expected geometry")
            return
        }
        XCTAssertEqual(geo.geometryType, .polyline)
        XCTAssertEqual(geo.coordinates.count, 3)
    }

    func testParseMixedTypes() throws {
        let json = Data("""
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [-122.0, 37.0]},
              "properties": {"name": "WP"}
            },
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [[[-122.0, 37.0], [-122.0, 38.0], [-121.0, 38.0], [-122.0, 37.0]]]
              },
              "properties": {"name": "Area"}
            },
            {
              "type": "Feature",
              "geometry": {"type": "LineString", "coordinates": [[-122.0, 37.0], [-121.0, 38.0]]},
              "properties": {"name": "Line"}
            }
          ]
        }
        """.utf8)

        let items = try GeoJSONImportService.parse(data: json)
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items[0].isWaypoint)
    }

    func testParseSingleFeature() throws {
        let json = Data("""
        {
          "type": "Feature",
          "geometry": {"type": "Point", "coordinates": [-122.0, 37.0]},
          "properties": {"name": "Single"}
        }
        """.utf8)

        let items = try GeoJSONImportService.parse(data: json)
        XCTAssertEqual(items.count, 1)
    }

    func testParseInvalidJSON() {
        let data = Data("not json".utf8)
        XCTAssertThrowsError(try GeoJSONImportService.parse(data: data))
    }

    func testParseDefaultNames() throws {
        let json = Data("""
        {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [-122.0, 37.0]},
            "properties": {}
          }]
        }
        """.utf8)

        let items = try GeoJSONImportService.parse(data: json)
        guard case .waypoint(let wp) = items[0] else {
            XCTFail("Expected waypoint")
            return
        }
        XCTAssertEqual(wp.name, "Imported Point")
    }
}
