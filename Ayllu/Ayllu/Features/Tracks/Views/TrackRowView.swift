import SwiftUI

/// List row component for displaying a track
struct TrackRowView: View {
    let track: Track

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(.secondary)

                Text(track.name)
                    .font(.headline)

                Spacer()

                if track.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Recording")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Distance and duration
            HStack(spacing: 16) {
                if let distance = track.distance {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption2)
                        Text(track.formattedDistance)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if let duration = track.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(track.formattedDuration)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            // Date
            Text(dateFormatter.string(from: track.startTime))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        TrackRowView(track: Track(
            id: 1,
            projectId: 1,
            name: "Morning Hike",
            startTime: Date().addingTimeInterval(-3_600),
            distance: 5_234,
            duration: 3_600
        ))

        TrackRowView(track: Track(
            id: 2,
            projectId: 1,
            name: "Trail Recording",
            startTime: Date(),
            isRecording: true
        ))
    }
}
