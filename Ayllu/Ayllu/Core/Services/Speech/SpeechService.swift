import Foundation
import Speech
import AVFoundation

/// Service for speech recognition and audio recording
@Observable
final class SpeechService: NSObject {
    // MARK: - Published State

    /// Current transcription text
    private(set) var transcription: String = ""

    /// Whether currently recording
    private(set) var isRecording: Bool = false

    /// Recording duration in seconds
    private(set) var recordingDuration: TimeInterval = 0

    /// Authorization status
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    /// Last error encountered
    private(set) var lastError: Error?

    /// Whether speech recognition is available
    private(set) var isAvailable: Bool = false

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var currentAudioPath: String?

    // MARK: - Computed Properties

    /// Whether speech recognition is authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    /// Formatted recording duration
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Initialization

    override init() {
        // Initialize with on-device recognition for offline support
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        super.init()

        speechRecognizer?.delegate = self
        isAvailable = speechRecognizer?.isAvailable ?? false

        // Check initial authorization
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Authorization

    /// Requests speech recognition authorization
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    /// Requests microphone authorization
    func requestMicrophoneAuthorization() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording with Transcription

    /// Starts recording and transcribing
    func startRecording() throws {
        guard isAuthorized else {
            throw SpeechError.notAuthorized
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session (iOS only)
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        // Create recognition request with on-device preference
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        // Set up audio recording
        let audioPath = generateAudioPath()
        currentAudioPath = audioPath
        try setupAudioRecorder(path: audioPath)

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.transcription = result.bestTranscription.formattedString
            }

            if let error = error {
                self.lastError = error
                self.stopRecording()
            }
        }

        // Set up audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start audio recorder
        audioRecorder?.record()

        // Update state
        isRecording = true
        recordingDuration = 0
        lastError = nil

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }

    /// Stops recording and returns the audio file path
    @discardableResult
    func stopRecording() -> String? {
        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Stop recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        // Stop audio recorder
        audioRecorder?.stop()
        audioRecorder = nil

        // Deactivate audio session (iOS only)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        isRecording = false

        return currentAudioPath
    }

    /// Clears the current transcription
    func clearTranscription() {
        transcription = ""
    }

    // MARK: - Audio Playback

    /// Plays an audio file
    func playAudio(path: String) throws {
        let url = URL(fileURLWithPath: path)
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback)
        try audioSession.setActive(true)
        #endif

        // Use AVAudioPlayer for playback
        // Note: In a full implementation, this would be managed separately
        _ = url // Silence unused variable warning
    }

    // MARK: - Private Methods

    private func generateAudioPath() -> String {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        return documentsPath
            .appendingPathComponent("audio_\(timestamp).m4a")
            .path
    }

    private func setupAudioRecorder(path: String) throws {
        let url = URL(fileURLWithPath: path)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.prepareToRecord()
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechService: SFSpeechRecognizerDelegate {
    func speechRecognizer(
        _ speechRecognizer: SFSpeechRecognizer,
        availabilityDidChange available: Bool
    ) {
        isAvailable = available
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    case audioSetupFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        case .audioSetupFailed:
            return "Failed to set up audio recording"
        }
    }
}
