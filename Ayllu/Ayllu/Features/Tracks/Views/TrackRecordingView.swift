import SwiftUI
import MapLibre
import CoreLocation

/// Full-screen recording UI for GPS tracks
struct TrackRecordingView: View {
    @Environment(TrackRecordingService.self) private var recordingService
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64

    @State private var showingStopConfirmation = false
    @State private var showingCancelConfirmation = false
    @State private var recordedCoordinates: [CLLocationCoordinate2D] = []
    @State private var mapCenter: CLLocationCoordinate2D?

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
        TrackRecordingMapView(
            recordedCoordinates: $recordedCoordinates,
            currentLocation: locationService.currentLocation,
            mapCenter: $mapCenter
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: locationService.currentLocation) { _, newLocation in
            if let coordinate = newLocation?.coordinate {
                // Update map center to follow user
                mapCenter = coordinate

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

// MARK: - Track Recording Map View

/// Lightweight MapLibre view for track recording preview
private struct TrackRecordingMapView: UIViewRepresentable {
    @Binding var recordedCoordinates: [CLLocationCoordinate2D]
    let currentLocation: CLLocation?
    @Binding var mapCenter: CLLocationCoordinate2D?

    private static let openTopoMapURL = "https://tile.opentopomap.org/{z}/{x}/{y}.png"

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Configure map settings
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        mapView.compassViewPosition = .topRight
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true

        // Set initial camera
        if let location = currentLocation {
            mapView.setCenter(location.coordinate, zoomLevel: 16, animated: false)
        } else {
            // Default to center of US
            mapView.setCenter(
                CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                zoomLevel: 4,
                animated: false
            )
        }

        // Configure OpenTopoMap style
        if let styleURL = Bundle.main.url(forResource: "OpenTopoMap-style", withExtension: "json") {
            mapView.styleURL = styleURL
        } else {
            // Fallback to demo style
            mapView.styleURL = URL(string: "https://demotiles.maplibre.org/style.json")
        }

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Update map center if changed
        if let center = mapCenter, !context.coordinator.hasSetInitialLocation {
            mapView.setCenter(center, zoomLevel: 16, animated: true)
            context.coordinator.hasSetInitialLocation = true
        } else if let center = mapCenter {
            mapView.setCenter(center, zoomLevel: max(mapView.zoomLevel, 16), animated: true)
        }

        // Update track polyline
        context.coordinator.updateTrackPolyline(mapView, coordinates: recordedCoordinates)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: TrackRecordingMapView
        var hasSetInitialLocation = false
        var currentPolyline: MLNPolyline?

        init(_ parent: TrackRecordingMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Add OpenTopoMap as raster source if not using bundled style
            if mapView.styleURL?.absoluteString == "https://demotiles.maplibre.org/style.json" {
                let options: [MLNTileSourceOption: Any] = [
                    .tileSize: NSNumber(value: 256),
                    .minimumZoomLevel: NSNumber(value: 1),
                    .maximumZoomLevel: NSNumber(value: 17)
                ]

                let source = MLNRasterTileSource(
                    identifier: "opentopomap",
                    tileURLTemplates: [TrackRecordingMapView.openTopoMapURL],
                    options: options
                )

                style.addSource(source)

                let rasterLayer = MLNRasterStyleLayer(identifier: "opentopomap-layer", source: source)
                style.addLayer(rasterLayer)
            }
        }

        func updateTrackPolyline(_ mapView: MLNMapView, coordinates: [CLLocationCoordinate2D]) {
            // Remove existing polyline
            if let polyline = currentPolyline {
                mapView.removeAnnotation(polyline)
            }

            // Add new polyline if we have coordinates
            guard coordinates.count >= 2 else { return }

            var coords = coordinates
            let polyline = MLNPolyline(coordinates: &coords, count: UInt(coords.count))
            mapView.addAnnotation(polyline)
            currentPolyline = polyline
        }

        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            return .systemRed
        }

        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat {
            return 3.0
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
