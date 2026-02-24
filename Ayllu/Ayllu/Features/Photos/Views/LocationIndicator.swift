import SwiftUI
import CoreLocation

/// Displays GPS status and accuracy as a pill indicator
struct LocationIndicator: View {
    let location: CLLocation?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(.caption, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var hasLocation: Bool {
        guard let location = location else { return false }
        return location.horizontalAccuracy >= 0
    }

    private var statusColor: Color {
        guard hasLocation, let location = location else { return .red }

        switch location.horizontalAccuracy {
        case ..<5:
            return .green
        case ..<10:
            return .green.opacity(0.8)
        case ..<25:
            return .yellow
        case ..<50:
            return .orange
        default:
            return .red
        }
    }

    private var statusText: String {
        guard hasLocation, let location = location else {
            return "No GPS"
        }

        let accuracy = location.horizontalAccuracy
        if accuracy < 5 {
            return "GPS: \(Int(accuracy))m"
        } else if accuracy < 100 {
            return "\(Int(accuracy))m accuracy"
        } else {
            return "GPS: \(Int(accuracy))m"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // No location
        LocationIndicator(location: nil)

        // Excellent accuracy
        LocationIndicator(location: CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: 0,
            horizontalAccuracy: 3,
            verticalAccuracy: 5,
            timestamp: Date()
        ))

        // Good accuracy
        LocationIndicator(location: CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: 0,
            horizontalAccuracy: 8,
            verticalAccuracy: 5,
            timestamp: Date()
        ))

        // Fair accuracy
        LocationIndicator(location: CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: 0,
            horizontalAccuracy: 20,
            verticalAccuracy: 5,
            timestamp: Date()
        ))

        // Poor accuracy
        LocationIndicator(location: CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: 0,
            horizontalAccuracy: 60,
            verticalAccuracy: 5,
            timestamp: Date()
        ))
    }
    .padding()
    .background(Color.gray)
}
