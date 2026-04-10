import SwiftUI
import AVFoundation
import CoreLocation

/// Main camera capture interface for taking geotagged photos
struct PhotoCaptureView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64
    let waypointId: Int64?

    @State private var cameraService = CameraService()
    @State private var capturedImage: UIImage?
    @State private var isCapturing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    @State private var exposureBias: Float = 0

    init(projectId: Int64, waypointId: Int64? = nil) {
        self.projectId = projectId
        self.waypointId = waypointId
    }

    var body: some View {
        ZStack {
            if let image = capturedImage {
                PhotoReviewView(
                    image: image,
                    projectId: projectId,
                    waypointId: waypointId,
                    location: locationService.currentLocation,
                    heading: locationService.currentHeading,
                    onSave: { caption in savePhoto(caption: caption) },
                    onRetake: { capturedImage = nil }
                )
            } else {
                cameraPreviewView
            }
        }
        .navigationTitle("Take Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { setupCamera() }
        .onDisappear { cameraService.stopSession() }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Camera Preview

    private var cameraPreviewView: some View {
        ZStack {
            CameraPreviewView(
                session: cameraService.session,
                onTapToFocus: { devicePoint, viewPoint in
                    handleTapToFocus(devicePoint: devicePoint, viewPoint: viewPoint)
                }
            )
            .ignoresSafeArea()

            // Focus indicator
            if showFocusIndicator, let point = focusPoint {
                FocusIndicatorView()
                    .position(point)
            }

            VStack(spacing: 0) {
                // Top bar: GPS + flip camera
                topBar

                Spacer()

                // Zoom slider
                zoomControl

                // Lens switcher + exposure
                HStack(alignment: .bottom) {
                    exposureControl
                        .frame(width: 50)

                    Spacer()

                    // Shutter
                    captureButton

                    Spacer()

                    // Flip camera
                    flipCameraButton
                        .frame(width: 50)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            LocationIndicator(location: locationService.currentLocation)
            Spacer()
            if cameraService.currentZoom > 1.05 {
                Text(String(format: "%.1fx", cameraService.currentZoom))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Zoom Control

    private var zoomControl: some View {
        VStack(spacing: 8) {
            // Lens picker (if multiple lenses available)
            if cameraService.availableLenses.count > 1 {
                HStack(spacing: 12) {
                    ForEach(cameraService.availableLenses) { lens in
                        Button {
                            cameraService.switchLens(lens)
                        } label: {
                            Text(lens.rawValue)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    cameraService.currentLens == lens
                                        ? Color.yellow : Color.white.opacity(0.3)
                                )
                                .foregroundStyle(
                                    cameraService.currentLens == lens ? .black : .white
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.bottom, 4)
            }

            // Zoom slider
            HStack(spacing: 8) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.white)

                Slider(
                    value: Binding(
                        get: { cameraService.currentZoom },
                        set: { cameraService.setZoom($0) }
                    ),
                    in: 1.0...cameraService.maxZoom
                )
                .tint(.yellow)

                Image(systemName: "plus.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Exposure Control

    private var exposureControl: some View {
        VStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)

            Slider(
                value: Binding(
                    get: { Double(exposureBias) },
                    set: {
                        exposureBias = Float($0)
                        cameraService.setExposureCompensation(Float($0))
                    }
                ),
                in: Double(cameraService.minExposureBias)...Double(cameraService.maxExposureBias)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 100)
            .frame(height: 100)
            .tint(.yellow)

            Image(systemName: "sun.min.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
        }
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 70, height: 70)
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                if isCapturing {
                    ProgressView()
                        .tint(.gray)
                }
            }
        }
        .disabled(isCapturing || !cameraService.isSessionRunning)
    }

    // MARK: - Flip Camera

    private var flipCameraButton: some View {
        Button {
            cameraService.toggleFrontBack()
        } label: {
            Image(systemName: "camera.rotate.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }

    // MARK: - Focus

    private func handleTapToFocus(devicePoint: CGPoint, viewPoint: CGPoint) {
        cameraService.focus(at: devicePoint)

        focusPoint = viewPoint
        showFocusIndicator = true

        withAnimation(.easeOut(duration: 1.5)) {
            showFocusIndicator = false
        }
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        Task {
            let authorized = await cameraService.requestAuthorization()
            guard authorized else {
                errorMessage = "Camera access is required to take photos."
                showingError = true
                return
            }

            do {
                try cameraService.configureSession()
                cameraService.startSession()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }

        locationService.startUpdatingLocation()
        locationService.startUpdatingHeading()
    }

    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true

        Task {
            do {
                let image = try await cameraService.capturePhoto()
                await MainActor.run {
                    capturedImage = image
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isCapturing = false
                }
            }
        }
    }

    private func savePhoto(caption: String?) {
        let storageService = PhotoStorageService()
        guard let image = capturedImage else { return }

        do {
            let paths = try storageService.savePhoto(
                image: image,
                location: locationService.currentLocation,
                heading: locationService.currentHeading,
                projectId: projectId
            )

            let photo = Photo(
                projectId: projectId,
                waypointId: waypointId,
                filePath: paths.photoPath,
                thumbnailPath: paths.thumbnailPath,
                caption: caption,
                latitude: locationService.currentLocation?.coordinate.latitude,
                longitude: locationService.currentLocation?.coordinate.longitude,
                altitude: locationService.currentLocation?.altitude,
                heading: locationService.currentHeading?.trueHeading
            )

            let repo = PhotoRepository(dbPool: database.dbPool)
            try repo.create(photo)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Focus Indicator

private struct FocusIndicatorView: View {
    @State private var scale: CGFloat = 1.5

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(.yellow, lineWidth: 2)
            .frame(width: 70, height: 70)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }
            }
    }
}

#Preview {
    NavigationStack {
        PhotoCaptureView(projectId: 1)
    }
}
