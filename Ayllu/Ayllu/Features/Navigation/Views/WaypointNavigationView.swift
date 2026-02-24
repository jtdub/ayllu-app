import SwiftUI
import CoreLocation
import UIKit

/// Full-screen navigation view for navigating to a waypoint
struct WaypointNavigationView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("useTrueNorth") private var useTrueNorth = false
    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters

    let targetWaypoint: Waypoint

    @State private var lastHapticDistance: Double?
    @State private var hasArrived = false

    // Distance thresholds for haptic feedback (in meters)
    private let hapticThresholds: [Double] = [100, 50, 25, 10, 5]
    private let arrivalThreshold: Double = 5

    var body: some View {
        VStack(spacing: 24) {
            // Waypoint name
            Text(targetWaypoint.name)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            // Large compass
            if let heading = currentHeading {
                CompassView(
                    heading: heading,
                    targetBearing: bearing,
                    size: 250
                )
                .animation(.easeInOut(duration: 0.3), value: heading)
            } else {
                // Placeholder compass when no heading available
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 250, height: 250)

                    VStack(spacing: 8) {
                        Image(systemName: "location.north.line")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Calibrating...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Distance display
            VStack(spacing: 4) {
                if let distance = distance {
                    Text(CoordinateFormatter.formatDistance(distance, unit: distanceUnit))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(hasArrived ? .green : .primary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: distance)
                } else {
                    Text("--")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text("to destination")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Bearing display
            if let bearing = bearing {
                VStack(spacing: 4) {
                    Text(GeoCalculator.formatBearing(bearing))
                        .font(.system(.title3, design: .monospaced))

                    Text(useTrueNorth ? "True bearing" : "Magnetic bearing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Arrival indicator
            if hasArrived {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("You have arrived!")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Coordinates at bottom
            VStack(spacing: 4) {
                Text("Target coordinates")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(CoordinateFormatter.format(
                    latitude: targetWaypoint.latitude,
                    longitude: targetWaypoint.longitude,
                    format: .decimal
                ))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Navigate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            locationService.startUpdatingLocation()
            locationService.startUpdatingHeading()
        }
        .onChange(of: distance) { _, newDistance in
            checkHapticFeedback(newDistance)
            checkArrival(newDistance)
        }
    }

    // MARK: - Computed Properties

    private var currentHeading: Double? {
        guard let heading = locationService.currentHeading else { return nil }
        let degrees = useTrueNorth ? heading.trueHeading : heading.magneticHeading
        return degrees >= 0 ? degrees : nil
    }

    private var distance: Double? {
        guard let location = locationService.currentLocation else { return nil }
        return GeoCalculator.distance(from: location, to: targetWaypoint)
    }

    private var bearing: Double? {
        guard let location = locationService.currentLocation else { return nil }
        return GeoCalculator.bearing(from: location, to: targetWaypoint)
    }

    // MARK: - Private Methods

    private func checkHapticFeedback(_ newDistance: Double?) {
        guard let distance = newDistance else { return }

        // Find the threshold we just crossed
        for threshold in hapticThresholds where distance <= threshold {
            if let lastDistance = lastHapticDistance, lastDistance > threshold {
                // Just crossed this threshold
                triggerHaptic(for: threshold)
                break
            }
        }

        lastHapticDistance = distance
    }

    private func triggerHaptic(for threshold: Double) {
        let generator: UIImpactFeedbackGenerator
        switch threshold {
        case 100:
            generator = UIImpactFeedbackGenerator(style: .light)
        case 50:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case 25:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case 10, 5:
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.success)
            return
        default:
            generator = UIImpactFeedbackGenerator(style: .medium)
        }
        generator.impactOccurred()
    }

    private func checkArrival(_ newDistance: Double?) {
        guard let distance = newDistance else { return }

        withAnimation {
            hasArrived = distance <= arrivalThreshold
        }
    }
}

#Preview {
    NavigationStack {
        WaypointNavigationView(targetWaypoint: Waypoint(
            id: 1,
            projectId: 1,
            name: "Test Site",
            latitude: 37.7749,
            longitude: -122.4194
        ))
    }
}
