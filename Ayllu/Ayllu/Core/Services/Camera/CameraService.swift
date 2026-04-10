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
    private(set) var currentZoom: CGFloat = 1.0
    private(set) var maxZoom: CGFloat = 10.0
    private(set) var isUsingFrontCamera: Bool = false
    private(set) var availableLenses: [CameraLens] = []
    private(set) var currentLens: CameraLens = .wide

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
        await MainActor.run { isAuthorized = granted }
        return granted
    }

    // MARK: - Session Configuration

    func configureSession() throws {
        guard isAuthorized else { throw CameraError.notAuthorized }
        sessionQueue.async { [weak self] in
            self?.configureSessionInternal(position: .back, lens: .wide)
        }
    }

    private func configureSessionInternal(position: AVCaptureDevice.Position, lens: CameraLens) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        // Remove existing inputs
        for input in session.inputs {
            session.removeInput(input)
        }

        // Find the requested camera
        let deviceType = lens.avDeviceType
        guard let camera = AVCaptureDevice.default(deviceType, for: .video, position: position) else {
            // Fall back to wide angle
            guard let fallback = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: position
            ) else {
                DispatchQueue.main.async { self.lastError = CameraError.cameraUnavailable }
                return
            }
            addCameraInput(fallback)
            return
        }

        addCameraInput(camera)
    }

    private func addCameraInput(_ camera: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            DispatchQueue.main.async { self.lastError = error }
            return
        }

        // Add photo output if not already added
        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        captureDevice = camera
        let zoom = camera.videoZoomFactor
        let maxZ = min(camera.activeFormat.videoMaxZoomFactor, 10.0)
        let front = camera.position == .front
        let lenses = Self.detectAvailableLenses(for: camera.position)
        let lens = CameraLens.from(deviceType: camera.deviceType)

        DispatchQueue.main.async {
            self.currentZoom = zoom
            self.maxZoom = maxZ
            self.isUsingFrontCamera = front
            self.availableLenses = lenses
            self.currentLens = lens
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
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    // MARK: - Camera Switching

    func toggleFrontBack() {
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .back : .front
        let lens: CameraLens = newPosition == .front ? .wide : currentLens
        sessionQueue.async { [weak self] in
            self?.configureSessionInternal(position: newPosition, lens: lens)
        }
    }

    func switchLens(_ lens: CameraLens) {
        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        sessionQueue.async { [weak self] in
            self?.configureSessionInternal(position: position, lens: lens)
        }
    }

    // MARK: - Zoom

    func setZoom(_ factor: CGFloat) {
        let targetZoom = min(max(factor, 1.0), maxZoom)

        sessionQueue.async { [weak self] in
            guard let device = self?.captureDevice else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = targetZoom
                DispatchQueue.main.async { self?.currentZoom = targetZoom }
            } catch {}
        }
    }

    // MARK: - Focus

    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let device = self?.captureDevice else { return }
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
            } catch {}
        }
    }

    // MARK: - Exposure

    func setExposureCompensation(_ bias: Float) {
        sessionQueue.async { [weak self] in
            guard let device = self?.captureDevice else { return }
            let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(clamped, completionHandler: nil)
            } catch {}
        }
    }

    var minExposureBias: Float { captureDevice?.minExposureTargetBias ?? -2.0 }
    var maxExposureBias: Float { captureDevice?.maxExposureTargetBias ?? 2.0 }

    // MARK: - Photo Capture

    func capturePhoto() async throws -> UIImage {
        guard isSessionRunning else { throw CameraError.sessionNotRunning }
        guard photoContinuation == nil else { throw CameraError.captureFailure }

        return try await withCheckedThrowingContinuation { continuation in
            photoContinuation = continuation
            sessionQueue.async { [weak self] in
                guard let self else { return }
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .auto
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - Lens Detection

    private static func detectAvailableLenses(
        for position: AVCaptureDevice.Position
    ) -> [CameraLens] {
        var lenses: [CameraLens] = []
        let types: [(CameraLens, AVCaptureDevice.DeviceType)] = [
            (.ultraWide, .builtInUltraWideCamera),
            (.wide, .builtInWideAngleCamera),
            (.telephoto, .builtInTelephotoCamera)
        ]
        for (lens, deviceType) in types
            where AVCaptureDevice.default(deviceType, for: .video, position: position) != nil {
            lenses.append(lens)
        }
        return lenses
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
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

        DispatchQueue.main.async { self.capturedImage = image }
        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}

// MARK: - Camera Lens

enum CameraLens: String, CaseIterable, Identifiable {
    case ultraWide = "0.5x"
    case wide = "1x"
    case telephoto = "2x"

    var id: String { rawValue }

    var avDeviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto: return .builtInTelephotoCamera
        }
    }

    static func from(deviceType: AVCaptureDevice.DeviceType) -> Self {
        switch deviceType {
        case .builtInUltraWideCamera: return .ultraWide
        case .builtInTelephotoCamera: return .telephoto
        default: return .wide
        }
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
        case .notAuthorized: return "Camera access not authorized"
        case .cameraUnavailable: return "Camera is not available"
        case .sessionNotRunning: return "Camera session is not running"
        case .captureFailure: return "Failed to capture photo"
        }
    }
}
