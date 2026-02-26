import SwiftUI
import MapKit

/// Full-screen recording UI for GPS tracks
struct TrackRecordingView: View {
    @Environment(TrackRecordingService.self) private var recordingService
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64

    @State private var showingStopConfirmation = false
    @State private var showingCancelConfirmation = false
    @State private var recordedCoordinates: [CLLocationCoordinate2D] = []
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top section: GPS indicator and status
                topSection
                    .padding()

                Spacer()

                // Center section: Live statistics
                statisticsSection
                    .padding()

                Spacer()

                // Map preview
                mapPreview
                    .frame(height: 200)
                    .padding(.horizontal)

                Spacer()

                // Bottom section: Control buttons
                controlButtons
                    .padding()
                    .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if recordingService.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(recordingService.isPaused ? .orange : .red)
                            .frame(width: 8, height: 8)
                        Text(recordingService.isPaused ? "Paused" : "Recording")
                            .foregroundStyle(.white)
                            .font(.headline)
                    }
                } else {
                    Text("Track Recording")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if recordingService.isRecording {
                        showingCancelConfirmation = true
                    } else {
                        dismiss()
                    }
                }
                .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .onAppear {
            startRecordingIfNeeded()
        }
        .alert("Stop Recording?", isPresented: $showingStopConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Stop & Save") {
                stopRecording()
            }
        } message: {
            Text("This will save the track with \(recordingService.pointCount) points.")
        }
        .alert("Cancel Recording?", isPresented: $showingCancelConfirmation) {
            Button("Keep Recording", role: .cancel) {}
            Button("Discard", role: .destructive) {
                cancelRecording()
            }
        } message: {
            Text("This will discard the track. All recorded data will be lost.")
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        HStack {
            // GPS signal indicator
            GPSSignalIndicator(signalQuality: locationService.signalQuality)

            Spacer()

            // Location accuracy
            if let accuracy = locationService.horizontalAccuracy {
                Text("±\(Int(accuracy))m")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        TrackStatisticsView(
            liveDistance: recordingService.liveDistance,
            liveDuration: recordingService.liveDuration,
            currentSpeed: recordingService.currentSpeed,
            currentElevation: recordingService.currentElevation,
            pointCount: recordingService.pointCount
        )
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        Map(position: .constant(.region(mapRegion))) {
            // Current location marker
            if let coordinate = locationService.currentCoordinate {
                Annotation("", coordinate: coordinate) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                }
            }

            // Track polyline
            if !recordedCoordinates.isEmpty {
                MapPolyline(coordinates: recordedCoordinates)
                    .stroke(.red, lineWidth: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: locationService.currentLocation) { _, newLocation in
            if let coordinate = newLocation?.coordinate {
                // Update map region to follow user
                mapRegion.center = coordinate

                // Add coordinate to polyline
                if recordingService.isRecording && !recordingService.isPaused {
                    recordedCoordinates.append(coordinate)

                    // Limit polyline to last 1000 points for performance
                    if recordedCoordinates.count > 1_000 {
                        recordedCoordinates.removeFirst(recordedCoordinates.count - 1_000)
                    }
                }
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 40) {
            if !recordingService.isRecording {
                // Start button
                Button {
                    startRecording()
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 70, height: 70)

                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }

                        Text("Start")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            } else {
                // Pause/Resume button
                Button {
                    if recordingService.isPaused {
                        recordingService.resumeRecording()
                    } else {
                        Task {
                            await recordingService.pauseRecording()
                        }
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.orange)
                                .frame(width: 70, height: 70)

                            Image(systemName: recordingService.isPaused ? "play.fill" : "pause.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }

                        Text(recordingService.isPaused ? "Resume" : "Pause")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

                // Stop button
                Button {
                    showingStopConfirmation = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 70, height: 70)

                            Image(systemName: "stop.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }

                        Text("Stop")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startRecordingIfNeeded() {
        guard !recordingService.isRecording else { return }
        // Auto-start on appear
        startRecording()
    }

    private func startRecording() {
        Task {
            do {
                try await recordingService.startRecording(projectId: projectId)
            } catch {
                // Handle error silently
            }
        }
    }

    private func stopRecording() {
        Task {
            do {
                _ = try await recordingService.stopRecording()
                dismiss()
            } catch {
                // Handle error silently
            }
        }
    }

    private func cancelRecording() {
        Task {
            do {
                try await recordingService.cancelRecording()
                dismiss()
            } catch {
                // Handle error silently
            }
        }
    }
}

// MARK: - GPS Signal Indicator

private struct GPSSignalIndicator: View {
    let signalQuality: SignalQuality

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: signalQuality.iconName)
                .foregroundStyle(signalColor)

            Text(signalQuality.rawValue)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var signalColor: Color {
        switch signalQuality {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .poor:
            return .orange
        case .veryPoor, .none:
            return .red
        }
    }
}

#Preview {
    NavigationStack {
        TrackRecordingView(projectId: 1)
    }
}
