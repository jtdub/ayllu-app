import Foundation

/// ViewModel for the note editor
@Observable
final class NoteEditorViewModel {
    // MARK: - State

    var title: String = ""
    var content: String = ""
    var transcription: String = ""
    var isRecording: Bool = false
    var audioFilePath: String?
    var error: Error?

    // MARK: - Dependencies

    private let repository: NoteRepository
    private let speechService: SpeechService
    let projectId: Int64
    let waypointId: Int64?
    private var existingNote: FieldNote?

    // MARK: - Computed Properties

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasContent: Bool {
        !content.isEmpty || !transcription.isEmpty || audioFilePath != nil
    }

    var isEditing: Bool {
        existingNote != nil
    }

    // MARK: - Initialization

    init(
        repository: NoteRepository,
        speechService: SpeechService,
        projectId: Int64,
        waypointId: Int64? = nil,
        existingNote: FieldNote? = nil
    ) {
        self.repository = repository
        self.speechService = speechService
        self.projectId = projectId
        self.waypointId = waypointId
        self.existingNote = existingNote

        if let note = existingNote {
            title = note.title
            content = note.content
            transcription = note.transcription ?? ""
            audioFilePath = note.audioFilePath
        } else {
            generateDefaultTitle()
        }
    }

    // MARK: - Actions

    private func generateDefaultTitle() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        title = "Note - \(dateFormatter.string(from: Date()))"
    }

    func startRecording() {
        do {
            try speechService.startRecording()
            isRecording = true
        } catch {
            self.error = error
        }
    }

    func stopRecording() {
        let path = speechService.stopRecording()
        audioFilePath = path
        transcription = speechService.transcription
        isRecording = false
    }

    func save() throws -> FieldNote {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)

        if var note = existingNote {
            note.title = trimmedTitle
            note.content = trimmedContent
            note.transcription = trimmedTranscription.isEmpty ? nil : trimmedTranscription
            note.audioFilePath = audioFilePath
            return try repository.update(note)
        } else {
            let note = FieldNote(
                projectId: projectId,
                waypointId: waypointId,
                title: trimmedTitle,
                content: trimmedContent,
                audioFilePath: audioFilePath,
                transcription: trimmedTranscription.isEmpty ? nil : trimmedTranscription
            )
            return try repository.create(note)
        }
    }
}
