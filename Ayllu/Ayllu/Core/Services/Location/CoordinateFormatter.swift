import Foundation
import CoreLocation
import UTMConversion

/// Formats coordinates in various standard formats
struct CoordinateFormatter {
    /// Available coordinate formats
    enum Format: String, CaseIterable, Codable {
        case decimal
        case dms
        case utm

        var displayName: String {
            switch self {
            case .decimal: return "Decimal Degrees"
            case .dms: return "Degrees Minutes Seconds"
            case .utm: return "UTM"
            }
        }

        var shortName: String {
            switch self {
            case .decimal: return "DD"
            case .dms: return "DMS"
            case .utm: return "UTM"
            }
        }

        var example: String {
            switch self {
            case .decimal: return "37.7749, -122.4194"
            case .dms: return "37° 46' 29.64\" N, 122° 25' 9.84\" W"
            case .utm: return "10S 551234 4182345"
            }
        }
    }

    // MARK: - Formatting

    /// Formats a coordinate in the specified format
    static func format(
        latitude: Double,
        longitude: Double,
        format: Format
    ) -> String {
        switch format {
        case .decimal:
            return formatDecimal(latitude: latitude, longitude: longitude)
        case .dms:
            return formatDMS(latitude: latitude, longitude: longitude)
        case .utm:
            return formatUTM(latitude: latitude, longitude: longitude)
        }
    }

    /// Formats a CLLocationCoordinate2D
    static func format(
        coordinate: CLLocationCoordinate2D,
        format: Format
    ) -> String {
        Self.format(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            format: format
        )
    }

    /// Formats a CLLocation
    static func format(
        location: CLLocation,
        format: Format
    ) -> String {
        Self.format(coordinate: location.coordinate, format: format)
    }

    // MARK: - Decimal Degrees

    /// Formats coordinates as decimal degrees (e.g., "37.7749, -122.4194")
    static func formatDecimal(latitude: Double, longitude: Double) -> String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }

    /// Formats latitude only as decimal
    static func formatDecimalLatitude(_ latitude: Double) -> String {
        String(format: "%.6f", latitude)
    }

    /// Formats longitude only as decimal
    static func formatDecimalLongitude(_ longitude: Double) -> String {
        String(format: "%.6f", longitude)
    }

    // MARK: - Degrees Minutes Seconds

    /// Formats coordinates as DMS (e.g., "37° 46' 29.64\" N, 122° 25' 9.84\" W")
    static func formatDMS(latitude: Double, longitude: Double) -> String {
        let latDMS = formatDMSComponent(latitude, isLatitude: true)
        let lonDMS = formatDMSComponent(longitude, isLatitude: false)
        return "\(latDMS), \(lonDMS)"
    }

    /// Formats a single DMS component
    static func formatDMSComponent(_ value: Double, isLatitude: Bool) -> String {
        let absolute = abs(value)
        let degrees = Int(absolute)
        let minutesDecimal = (absolute - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60

        let direction: String
        if isLatitude {
            direction = value >= 0 ? "N" : "S"
        } else {
            direction = value >= 0 ? "E" : "W"
        }

        return String(format: "%d° %d' %.2f\" %@", degrees, minutes, seconds, direction)
    }

    /// Formats latitude only as DMS
    static func formatDMSLatitude(_ latitude: Double) -> String {
        formatDMSComponent(latitude, isLatitude: true)
    }

    /// Formats longitude only as DMS
    static func formatDMSLongitude(_ longitude: Double) -> String {
        formatDMSComponent(longitude, isLatitude: false)
    }

    // MARK: - UTM

    /// Formats coordinates as UTM (e.g., "10S 551234 4182345")
    static func formatUTM(latitude: Double, longitude: Double) -> String {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Validate coordinate range
        guard latitude >= -80 && latitude <= 84 else {
            // UTM doesn't cover polar regions, fall back to decimal
            return formatDecimal(latitude: latitude, longitude: longitude)
        }

        let utmCoordinate = coordinate.utmCoordinate()
        let zone = utmCoordinate.zone
        let hemisphere = utmCoordinate.hemisphere == .northern ? "N" : "S"
        let easting = Int(utmCoordinate.easting)
        let northing = Int(utmCoordinate.northing)

        return String(format: "%d%@ %d %d", zone, hemisphere, easting, northing)
    }

    /// Returns the UTM zone for a coordinate
    static func utmZone(latitude: Double, longitude: Double) -> String? {
        guard latitude >= -80 && latitude <= 84 else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let utmCoordinate = coordinate.utmCoordinate()
        let hemisphere = utmCoordinate.hemisphere == .northern ? "N" : "S"
        return "\(utmCoordinate.zone)\(hemisphere)"
    }

    // MARK: - Parsing

    /// Parses a decimal coordinate string
    static func parseDecimal(_ string: String) -> CLLocationCoordinate2D? {
        let components = string.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]),
              isValidLatitude(latitude),
              isValidLongitude(longitude) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Parses a DMS coordinate string
    static func parseDMS(_ string: String) -> CLLocationCoordinate2D? {
        // Pattern: "37° 46' 29.64\" N, 122° 25' 9.84\" W"
        let pattern = #"(\d+)°\s*(\d+)'\s*([\d.]+)\"\s*([NSEW]),?\s*(\d+)°\s*(\d+)'\s*([\d.]+)\"\s*([NSEW])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }

        func extractGroup(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: string) else { return nil }
            return String(string[range])
        }

        guard let latDeg = extractGroup(1).flatMap({ Int($0) }),
              let latMin = extractGroup(2).flatMap({ Int($0) }),
              let latSec = extractGroup(3).flatMap({ Double($0) }),
              let latDir = extractGroup(4),
              let lonDeg = extractGroup(5).flatMap({ Int($0) }),
              let lonMin = extractGroup(6).flatMap({ Int($0) }),
              let lonSec = extractGroup(7).flatMap({ Double($0) }),
              let lonDir = extractGroup(8) else {
            return nil
        }

        var latitude = Double(latDeg) + Double(latMin) / 60.0 + latSec / 3_600.0
        var longitude = Double(lonDeg) + Double(lonMin) / 60.0 + lonSec / 3_600.0

        if latDir.uppercased() == "S" { latitude = -latitude }
        if lonDir.uppercased() == "W" { longitude = -longitude }

        guard isValidLatitude(latitude), isValidLongitude(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - Validation

    /// Validates a latitude value
    static func isValidLatitude(_ latitude: Double) -> Bool {
        latitude >= -90 && latitude <= 90
    }

    /// Validates a longitude value
    static func isValidLongitude(_ longitude: Double) -> Bool {
        longitude >= -180 && longitude <= 180
    }

    /// Validates a coordinate
    static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        isValidLatitude(coordinate.latitude) && isValidLongitude(coordinate.longitude)
    }

    /// Validates a coordinate
    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        isValidLatitude(latitude) && isValidLongitude(longitude)
    }
}

// MARK: - Altitude Formatting

extension CoordinateFormatter {
    /// Distance unit for display
    enum DistanceUnit: String, CaseIterable, Codable {
        case meters
        case feet

        var displayName: String {
            switch self {
            case .meters: return "Meters"
            case .feet: return "Feet"
            }
        }

        var abbreviation: String {
            switch self {
            case .meters: return "m"
            case .feet: return "ft"
            }
        }
    }

    /// Formats altitude with units
    static func formatAltitude(_ meters: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .meters:
            return String(format: "%.1f m", meters)
        case .feet:
            let feet = meters * 3.28084
            return String(format: "%.1f ft", feet)
        }
    }

    /// Formats distance with units
    static func formatDistance(_ meters: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .meters:
            if meters < 1_000 {
                return String(format: "%.1f m", meters)
            } else {
                return String(format: "%.2f km", meters / 1_000)
            }
        case .feet:
            let feet = meters * 3.28084
            if feet < 5_280 {
                return String(format: "%.1f ft", feet)
            } else {
                let miles = feet / 5_280
                return String(format: "%.2f mi", miles)
            }
        }
    }

    /// Formats accuracy with units
    static func formatAccuracy(_ meters: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .meters:
            return String(format: "±%.1f m", meters)
        case .feet:
            let feet = meters * 3.28084
            return String(format: "±%.1f ft", feet)
        }
    }
}
