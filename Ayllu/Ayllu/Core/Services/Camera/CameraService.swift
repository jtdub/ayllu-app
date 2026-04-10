import AVFoundation
import UIKit

/// Service for managing camera capture using AVCaptureSession
@Observable
final class CameraService: NSObject {
    // MARK: - Published State

    private(set) var isAuthorized: Bool = false
    private(set) var isSessionRunning: Bool = false
    private(set) var capturedImage: UIImage?
    private(set) var lastError: Error?

    /// Current zoom factor (1.0 = no zoom)
    private(set) var currentZoom: CGFloat = 1.0
    /// Maximum zoom factor for the current device
    private(set) var maxZoom: CGFloat = 10.0

    // MARK: - Internal Properties

    let session = AVCaptureSession()

    // MARK: - Private Properties

    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private let sessionQueue = DispatchQueue(label: "com.ayllu.camera.session")
    private var captureDevice: AVCaptureDevice?

    // MARK: - Initialization

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined, .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func requestAuthorization() async -> Bool {
        guard !isAuthorized else { return true }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            isAuthorized = granted
        }
        return granted
    }

    // MARK: - Session Configuration

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

        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else {
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

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        captureDevice = camera
        DispatchQueue.main.async {
            self.maxZoom = min(camera.activeFormat.videoMaxZoomFactor, 10.0)
        }
    }

    // MARK: - Session Control

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Zoom

    func setZoom(_ factor: CGFloat) {
        guard let device = captureDevice else { return }
        let clamped = min(max(factor, 1.0), maxZoom)

        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = clamped
                DispatchQueue.main.async {
                    self?.currentZoom = clamped
                }
            } catch {
                // Zoom change failed silently
            }
        }
    }

    // MARK: - Focus

    /// Focus at a point in the preview layer's coordinate space (0-1, 0-1)
    func focus(at point: CGPoint) {
        guard let device = captureDevice else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
            } catch {
                // Focus change failed silently
            }
        }
    }

    // MARK: - Exposure

    func setExposureCompensation(_ bias: Float) {
        guard let device = captureDevice else { return }
        let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(clamped, completionHandler: nil)
            } catch {
                // Exposure change failed silently
            }
        }
    }

    var minExposureBias: Float {
        captureDevice?.minExposureTargetBias ?? -2.0
    }

    var maxExposureBias: Float {
        captureDevice?.maxExposureTargetBias ?? 2.0
    }

    // MARK: - Photo Capture

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
