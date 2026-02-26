import SwiftUI

/// Reusable component for displaying track statistics
struct TrackStatisticsView: View {
    let track: Track?
    let liveDistance: Double?
    let liveDuration: TimeInterval?
    let currentSpeed: Double?
    let currentElevation: Double?
    let pointCount: Int?

    init(
        track: Track? = nil,
        liveDistance: Double? = nil,
        liveDuration: TimeInterval? = nil,
        currentSpeed: Double? = nil,
        currentElevation: Double? = nil,
        pointCount: Int? = nil
    ) {
        self.track = track
        self.liveDistance = liveDistance
        self.liveDuration = liveDuration
        self.currentSpeed = currentSpeed
        self.currentElevation = currentElevation
        self.pointCount = pointCount
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                StatisticCell(
                    label: "Distance",
                    value: distanceValue,
                    icon: "arrow.left.and.right"
                )

                StatisticCell(
                    label: "Duration",
                    value: durationValue,
                    icon: "clock"
                )
            }

            GridRow {
                StatisticCell(
                    label: "Avg Speed",
                    value: averageSpeedValue,
                    icon: "speedometer"
                )

                StatisticCell(
                    label: "Current Speed",
                    value: currentSpeedValue,
                    icon: "gauge"
                )
            }

            GridRow {
                StatisticCell(
                    label: "Elevation",
                    value: elevationValue,
                    icon: "mountain.2"
                )

                StatisticCell(
                    label: "Elev. Gain",
                    value: elevationGainValue,
                    icon: "arrow.up.right"
                )
            }

            GridRow {
                StatisticCell(
                    label: "Elev. Loss",
                    value: elevationLossValue,
                    icon: "arrow.down.right"
                )

                StatisticCell(
                    label: "Points",
                    value: pointsValue,
                    icon: "mappin.circle"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Values

    private var distanceValue: String {
        if let liveDistance = liveDistance {
            return formatDistance(liveDistance)
        } else if let track = track, let distance = track.distance {
            return formatDistance(distance)
        }
        return "—"
    }

    private var durationValue: String {
        if let liveDuration = liveDuration {
            return formatDuration(liveDuration)
        } else if let track = track, let duration = track.duration {
            return formatDuration(duration)
        }
        return "—"
    }

    private var averageSpeedValue: String {
        if let track = track,
           let distance = track.distance,
           let duration = track.duration,
           duration > 0 {
            let avgSpeed = distance / duration  // m/s
            return String(format: "%.1f km/h", avgSpeed * 3.6)
        } else if let liveDistance = liveDistance,
                  let liveDuration = liveDuration,
                  liveDuration > 0 {
            let avgSpeed = liveDistance / liveDuration
            return String(format: "%.1f km/h", avgSpeed * 3.6)
        }
        return "—"
    }

    private var currentSpeedValue: String {
        if let currentSpeed = currentSpeed, currentSpeed >= 0 {
            return String(format: "%.1f km/h", currentSpeed * 3.6)
        }
        return "—"
    }

    private var elevationValue: String {
        if let currentElevation = currentElevation {
            return String(format: "%.0f m", currentElevation)
        }
        return "—"
    }

    private var elevationGainValue: String {
        if let track = track, let gain = track.elevationGain {
            return String(format: "%.0f m", gain)
        }
        return "—"
    }

    private var elevationLossValue: String {
        if let track = track, let loss = track.elevationLoss {
            return String(format: "%.0f m", loss)
        }
        return "—"
    }

    private var pointsValue: String {
        if let pointCount = pointCount {
            return "\(pointCount)"
        }
        return "—"
    }

    // MARK: - Formatters

    private func formatDistance(_ distance: Double) -> String {
        if distance < 1_000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.2f km", distance / 1_000)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3_600
        let minutes = (Int(duration) % 3_600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Statistic Cell

private struct StatisticCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Completed Track") {
    TrackStatisticsView(
        track: Track(
            id: 1,
            projectId: 1,
            name: "Morning Hike",
            startTime: Date().addingTimeInterval(-3_600),
            endTime: Date(),
            distance: 5_234,
            duration: 3_600,
            elevationGain: 234,
            elevationLoss: 189
        ),
        pointCount: 512
    )
    .padding()
}

#Preview("Live Recording") {
    TrackStatisticsView(
        liveDistance: 1_234,
        liveDuration: 845,
        currentSpeed: 1.5,
        currentElevation: 234,
        pointCount: 128
    )
    .padding()
}
