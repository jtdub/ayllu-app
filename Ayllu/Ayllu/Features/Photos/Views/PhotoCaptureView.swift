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

    init(projectId: Int64, waypointId: Int64? = nil) {
        self.projectId = projectId
        self.waypointId = waypointId
    }

    var body: some View {
        ZStack {
            if let image = capturedImage {
                // Review captured photo
                PhotoReviewView(
                    image: image,
                    projectId: projectId,
                    waypointId: waypointId,
                    location: locationService.currentLocation,
                    heading: locationService.currentHeading,
                    onSave: { caption in
                        savePhoto(caption: caption)
                    },
                    onRetake: {
                        capturedImage = nil
                    }
                )
            } else {
                // Camera preview
                cameraPreviewView
            }
        }
        .navigationTitle("Take Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Camera Preview

    private var cameraPreviewView: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraService.session)
                .ignoresSafeArea()

            // Overlays
            VStack {
                // GPS indicator at top
                HStack {
                    LocationIndicator(location: locationService.currentLocation)
                    Spacer()
                }
                .padding()

                Spacer()

                // Capture button at bottom
                captureButton
                    .padding(.bottom, 40)
            }
        }
    }

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

    // MARK: - Private Methods

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

        // Start location updates for geotagging
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

            // Create Photo record
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

#Preview {
    NavigationStack {
        PhotoCaptureView(projectId: 1)
    }
}
