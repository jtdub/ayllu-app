import SwiftUI

/// Animated button for voice recording
struct VoiceRecordingButton: View {
    let isRecording: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var animationAmount: CGFloat = 1.0

    var body: some View {
        Button {
            if isRecording {
                onStop()
            } else {
                onStart()
            }
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.accentColor)
                        .frame(width: 44, height: 44)

                    if isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .frame(width: 44, height: 44)
                            .scaleEffect(animationAmount)
                            .opacity(2 - animationAmount)
                            .animation(
                                .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                value: animationAmount
                            )
                    }

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading) {
                    Text(isRecording ? "Recording..." : "Start Recording")
                        .font(.headline)

                    Text(isRecording ? "Tap to stop" : "Tap to record voice note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if isRecording {
                animationAmount = 2
            }
        }
        .onChange(of: isRecording) { _, newValue in
            animationAmount = newValue ? 2 : 1
        }
    }
}

// MARK: - Compact Version

struct CompactVoiceRecordingButton: View {
    let isRecording: Bool
    let duration: TimeInterval
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var animationAmount: CGFloat = 1.0

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Button {
            if isRecording {
                onStop()
            } else {
                onStart()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 60, height: 60)

                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .scaleEffect(animationAmount)
                        .opacity(2 - animationAmount)
                        .animation(
                            .easeInOut(duration: 1)
                                .repeatForever(autoreverses: false),
                            value: animationAmount
                        )

                    Text(formattedDuration)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 24))
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if isRecording {
                animationAmount = 2
            }
        }
        .onChange(of: isRecording) { _, newValue in
            animationAmount = newValue ? 2 : 1
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VoiceRecordingButton(
            isRecording: false,
            onStart: {},
            onStop: {}
        )

        VoiceRecordingButton(
            isRecording: true,
            onStart: {},
            onStop: {}
        )

        CompactVoiceRecordingButton(
            isRecording: true,
            duration: 65,
            onStart: {},
            onStop: {}
        )
    }
    .padding()
}
