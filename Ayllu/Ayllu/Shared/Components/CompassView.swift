import SwiftUI
import CoreLocation

/// A compass display that shows current heading
struct CompassView: View {
    let heading: Double
    let targetBearing: Double?
    let size: CGFloat

    init(heading: Double, targetBearing: Double? = nil, size: CGFloat = 100) {
        self.heading = heading
        self.targetBearing = targetBearing
        self.size = size
    }

    var body: some View {
        ZStack {
            // Compass rose background
            CompassRose(size: size)
                .rotationEffect(.degrees(-heading))

            // Target bearing indicator
            if let target = targetBearing {
                TargetIndicator(size: size)
                    .rotationEffect(.degrees(target - heading))
            }

            // Center dot
            Circle()
                .fill(Color.primary)
                .frame(width: size * 0.06, height: size * 0.06)

            // Heading indicator (always points up)
            HeadingIndicator(size: size)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Compass Rose

private struct CompassRose: View {
    let size: CGFloat

    private let cardinals = ["N", "E", "S", "W"]
    private let intercardinals = ["NE", "SE", "SW", "NW"]

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)

            // Degree marks
            ForEach(0..<36, id: \.self) { index in
                let isCardinal = index.isMultiple(of: 9)
                Rectangle()
                    .fill(isCardinal ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: isCardinal ? 2 : 1, height: isCardinal ? size * 0.08 : size * 0.04)
                    .offset(y: -size / 2 + (isCardinal ? size * 0.04 : size * 0.02))
                    .rotationEffect(.degrees(Double(index) * 10))
            }

            // Cardinal labels
            ForEach(0..<4, id: \.self) { index in
                Text(cardinals[index])
                    .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                    .foregroundStyle(index == 0 ? Color.red : Color.primary)
                    .offset(y: -size * 0.35)
                    .rotationEffect(.degrees(Double(index) * 90))
            }

            // Intercardinal labels
            ForEach(0..<4, id: \.self) { index in
                Text(intercardinals[index])
                    .font(.system(size: size * 0.08, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .offset(y: -size * 0.35)
                    .rotationEffect(.degrees(Double(index) * 90 + 45))
            }
        }
    }
}

// MARK: - Heading Indicator

private struct HeadingIndicator: View {
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color.red)
                .frame(width: size * 0.08, height: size * 0.12)

            Spacer()
        }
        .frame(height: size * 0.5)
    }
}

// MARK: - Target Indicator

private struct TargetIndicator: View {
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.blue)
                .frame(width: size * 0.08, height: size * 0.08)

            Spacer()
        }
        .frame(height: size * 0.45)
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Compact Compass

/// A smaller compass suitable for inline display
struct CompactCompassView: View {
    let heading: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.north.fill")
                .rotationEffect(.degrees(-heading))
                .foregroundStyle(.red)

            Text(GeoCalculator.formatBearing(heading))
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Heading Display

/// Displays heading with magnetic/true north option
struct HeadingDisplayView: View {
    let heading: CLHeading?
    let showTrueNorth: Bool

    init(heading: CLHeading?, showTrueNorth: Bool = false) {
        self.heading = heading
        self.showTrueNorth = showTrueNorth
    }

    private var displayHeading: Double? {
        guard let heading = heading else { return nil }
        return showTrueNorth ? heading.trueHeading : heading.magneticHeading
    }

    private var headingLabel: String {
        showTrueNorth ? "True" : "Magnetic"
    }

    var body: some View {
        if let degrees = displayHeading, degrees >= 0 {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "location.north.fill")
                        .foregroundStyle(.red)
                    Text(GeoCalculator.formatBearing(degrees))
                        .font(.system(.body, design: .monospaced))
                }
                Text(headingLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "location.north.fill")
                    .foregroundStyle(.secondary)
                Text("--°")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Compass") {
    VStack(spacing: 20) {
        CompassView(heading: 45, targetBearing: 90, size: 200)

        CompassView(heading: 0, size: 150)

        CompactCompassView(heading: 270)

        HeadingDisplayView(heading: nil)
    }
    .padding()
}
