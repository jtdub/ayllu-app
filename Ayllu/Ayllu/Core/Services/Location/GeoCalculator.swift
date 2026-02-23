import Foundation
import CoreLocation

/// Provides geographic calculations for distance, bearing, and navigation
struct GeoCalculator {
    // MARK: - Constants

    /// Earth's mean radius in meters (WGS-84)
    static let earthRadius: Double = 6_371_000

    // MARK: - Distance Calculations

    /// Calculates the great-circle distance between two coordinates using the Haversine formula
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Destination coordinate
    /// - Returns: Distance in meters
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians
        let deltaLat = (to.latitude - from.latitude).degreesToRadians
        let deltaLon = (to.longitude - from.longitude).degreesToRadians

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    /// Calculates distance between two waypoints
    static func distance(from: Waypoint, to: Waypoint) -> Double {
        distance(from: from.coordinate, to: to.coordinate)
    }

    /// Calculates distance from a location to a waypoint
    static func distance(from location: CLLocation, to waypoint: Waypoint) -> Double {
        distance(from: location.coordinate, to: waypoint.coordinate)
    }

    // MARK: - Bearing Calculations

    /// Calculates the initial bearing (azimuth) from one coordinate to another
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Destination coordinate
    /// - Returns: Bearing in degrees (0-360, where 0 is north)
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians
        let deltaLon = (to.longitude - from.longitude).degreesToRadians

        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        let bearing = atan2(x, y).radiansToDegrees
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculates bearing between two waypoints
    static func bearing(from: Waypoint, to: Waypoint) -> Double {
        bearing(from: from.coordinate, to: to.coordinate)
    }

    /// Calculates bearing from a location to a waypoint
    static func bearing(from location: CLLocation, to waypoint: Waypoint) -> Double {
        bearing(from: location.coordinate, to: waypoint.coordinate)
    }

    // MARK: - Magnetic Declination

    /// Converts true north bearing to magnetic bearing
    /// - Parameters:
    ///   - trueBearing: Bearing relative to true north
    ///   - declination: Magnetic declination (positive = east, negative = west)
    /// - Returns: Bearing relative to magnetic north
    static func magneticBearing(trueBearing: Double, declination: Double) -> Double {
        var magnetic = trueBearing - declination
        if magnetic < 0 { magnetic += 360 }
        if magnetic >= 360 { magnetic -= 360 }
        return magnetic
    }

    /// Converts magnetic bearing to true north bearing
    static func trueBearing(magneticBearing: Double, declination: Double) -> Double {
        var trueNorth = magneticBearing + declination
        if trueNorth < 0 { trueNorth += 360 }
        if trueNorth >= 360 { trueNorth -= 360 }
        return trueNorth
    }

    // MARK: - Destination Point

    /// Calculates the destination point given start, bearing, and distance
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - bearing: Bearing in degrees
    ///   - distance: Distance in meters
    /// - Returns: Destination coordinate
    static func destination(
        from: CLLocationCoordinate2D,
        bearing: Double,
        distance: Double
    ) -> CLLocationCoordinate2D {
        let lat1 = from.latitude.degreesToRadians
        let lon1 = from.longitude.degreesToRadians
        let brng = bearing.degreesToRadians
        let angularDistance = distance / earthRadius

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(brng)
        )
        let lon2 = lon1 + atan2(
            sin(brng) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2.radiansToDegrees,
            longitude: lon2.radiansToDegrees
        )
    }

    // MARK: - Formatting

    /// Formats bearing as cardinal direction (N, NE, E, etc.)
    static func cardinalDirection(bearing: Double) -> String {
        let directions = [
            "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
        ]
        let index = Int((bearing + 11.25) / 22.5) % 16
        return directions[index]
    }

    /// Formats bearing with degrees and cardinal direction
    static func formatBearing(_ bearing: Double) -> String {
        let cardinal = cardinalDirection(bearing: bearing)
        return String(format: "%.0f° %@", bearing, cardinal)
    }

    /// Formats bearing with only degrees
    static func formatBearingDegrees(_ bearing: Double) -> String {
        String(format: "%.0f°", bearing)
    }
}

// MARK: - Double Extensions

private extension Double {
    var degreesToRadians: Double {
        self * .pi / 180
    }

    var radiansToDegrees: Double {
        self * 180 / .pi
    }
}
