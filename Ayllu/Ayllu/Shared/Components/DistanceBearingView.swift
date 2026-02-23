import SwiftUI
import CoreLocation

/// Displays distance and bearing between two points
struct DistanceBearingView: View {
    let distance: Double
    let bearing: Double
    let distanceUnit: CoordinateFormatter.DistanceUnit

    init(
        distance: Double,
        bearing: Double,
        distanceUnit: CoordinateFormatter.DistanceUnit = .meters
    ) {
        self.distance = distance
        self.bearing = bearing
        self.distanceUnit = distanceUnit
    }

    init(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        distanceUnit: CoordinateFormatter.DistanceUnit = .meters
    ) {
        self.distance = GeoCalculator.distance(from: from, to: to)
        self.bearing = GeoCalculator.bearing(from: from, to: to)
        self.distanceUnit = distanceUnit
    }

    var body: some View {
        HStack(spacing: 16) {
            // Distance
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(CoordinateFormatter.formatDistance(distance, unit: distanceUnit))
                        .font(.system(.body, design: .monospaced))
                } icon: {
                    Image(systemName: "arrow.left.and.right")
                }

                Text("Distance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            // Bearing
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(GeoCalculator.formatBearing(bearing))
                        .font(.system(.body, design: .monospaced))
                } icon: {
                    Image(systemName: "location.north.fill")
                        .foregroundStyle(.red)
                }

                Text("Bearing")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Distance to Waypoint Card

/// A card showing distance and bearing to a waypoint
struct DistanceToWaypointCard: View {
    let waypoint: Waypoint
    let currentLocation: CLLocation?
    let currentHeading: CLHeading?

    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters

    private var distance: Double? {
        guard let location = currentLocation else { return nil }
        return GeoCalculator.distance(from: location, to: waypoint)
    }

    private var bearing: Double? {
        guard let location = currentLocation else { return nil }
        return GeoCalculator.bearing(from: location, to: waypoint)
    }

    private var relativeBearing: Double? {
        guard let bearing = bearing,
              let heading = currentHeading,
              heading.magneticHeading >= 0 else { return nil }
        var relative = bearing - heading.magneticHeading
        if relative < 0 { relative += 360 }
        return relative
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if let category = waypoint.category {
                    Image(systemName: category.iconName)
                        .foregroundStyle(.secondary)
                }
                Text(waypoint.name)
                    .font(.headline)
                Spacer()
            }

            if let dist = distance, let bear = bearing {
                HStack(spacing: 20) {
                    // Distance
                    VStack(spacing: 4) {
                        Text(CoordinateFormatter.formatDistance(dist, unit: distanceUnit))
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                        Text("Distance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Bearing
                    VStack(spacing: 4) {
                        Text(GeoCalculator.formatBearing(bear))
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                        Text("Bearing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Direction indicator
                    if let relative = relativeBearing {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.title2)
                                .rotationEffect(.degrees(relative))
                                .foregroundStyle(.blue)
                            Text("Direction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                    Text("Waiting for location...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Waypoint Distance List Row

/// A list row showing waypoint with distance from current location
struct WaypointDistanceRow: View {
    let waypoint: Waypoint
    let currentLocation: CLLocation?
    let coordinateFormat: CoordinateFormatter.Format

    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters

    private var distance: Double? {
        guard let location = currentLocation else { return nil }
        return GeoCalculator.distance(from: location, to: waypoint)
    }

    private var bearing: Double? {
        guard let location = currentLocation else { return nil }
        return GeoCalculator.bearing(from: location, to: waypoint)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let category = waypoint.category {
                    Image(systemName: category.iconName)
                        .foregroundStyle(.secondary)
                }

                Text(waypoint.name)
                    .font(.headline)

                Spacer()

                if let dist = distance {
                    Text(CoordinateFormatter.formatDistance(dist, unit: distanceUnit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(CoordinateFormatter.format(
                    latitude: waypoint.latitude,
                    longitude: waypoint.longitude,
                    format: coordinateFormat
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)

                Spacer()

                if let bear = bearing {
                    Text(GeoCalculator.formatBearing(bear))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 20) {
        DistanceBearingView(
            distance: 1_234.5,
            bearing: 45.0
        )

        DistanceToWaypointCard(
            waypoint: Waypoint(
                projectId: 1,
                name: "Test Point",
                latitude: 37.7749,
                longitude: -122.4194,
                category: .site
            ),
            currentLocation: CLLocation(latitude: 37.7850, longitude: -122.4094),
            currentHeading: nil
        )
    }
    .padding()
}
