import AVFoundation
import UIKit
import Combine

/// Service for managing camera capture using AVCaptureSession
@Observable
final class CameraService: NSObject {
    // MARK: - Published State

    /// Whether the camera is authorized
    private(set) var isAuthorized: Bool = false

    /// Whether the session is running
    private(set) var isSessionRunning: Bool = false

    /// Last captured image
    private(set) var capturedImage: UIImage?

    /// Last error encountered
    private(set) var lastError: Error?

    // MARK: - Internal Properties

    let session = AVCaptureSession()

    // MARK: - Private Properties

    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private let sessionQueue = DispatchQueue(label: "com.ayllu.camera.session")

    // MARK: - Initialization

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    /// Checks current camera authorization status
    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = false
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    /// Requests camera authorization
    func requestAuthorization() async -> Bool {
        guard !isAuthorized else { return true }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            isAuthorized = granted
        }
        return granted
    }

    // MARK: - Session Configuration

    /// Configures the capture session
    func configureSession() throws {
        guard isAuthorized else {
            throw CameraError.notAuthorized
        }

        sessionQueue.async { [weak self] in
            self?.configureSessionInternal()
        }
    }

    private func configureSessionInternal() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Set session preset
        session.sessionPreset = .photo

        // Add video input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async {
                self.lastError = CameraError.cameraUnavailable
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            DispatchQueue.main.async {
                self.lastError = error
            }
            return
        }

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
    }

    // MARK: - Session Control

    /// Starts the capture session
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    /// Stops the capture session
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Photo Capture

    /// Captures a photo and returns it
    func capturePhoto() async throws -> UIImage {
        guard isSessionRunning else {
            throw CameraError.sessionNotRunning
        }

        return try await withCheckedThrowingContinuation { continuation in
            photoContinuation = continuation

            sessionQueue.async { [weak self] in
                guard let self = self else { return }

                let settings = AVCapturePhotoSettings()
                settings.flashMode = .auto

                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            photoContinuation?.resume(throwing: error)
            photoContinuation = nil
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoContinuation?.resume(throwing: CameraError.captureFailure)
            photoContinuation = nil
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
        }

        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}

// MARK: - Camera Errors

enum CameraError: LocalizedError {
    case notAuthorized
    case cameraUnavailable
    case sessionNotRunning
    case captureFailure

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access not authorized"
        case .cameraUnavailable:
            return "Camera is not available"
        case .sessionNotRunning:
            return "Camera session is not running"
        case .captureFailure:
            return "Failed to capture photo"
        }
    }
}
