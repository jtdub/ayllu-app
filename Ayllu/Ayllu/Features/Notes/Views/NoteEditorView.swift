import SwiftUI

/// Editor view for creating or editing a field note
struct NoteEditorView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(SpeechService.self) private var speechService
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64
    let existingNote: FieldNote?

    @State private var viewModel: NoteEditorViewModel?
    @State private var showingDiscardAlert = false
    @State private var showingPermissionAlert = false
    @State private var permissionStatus: PermissionStatus = .unknown

    enum PermissionStatus {
        case unknown, authorized, denied
    }

    init(projectId: Int64, existingNote: FieldNote? = nil) {
        self.projectId = projectId
        self.existingNote = existingNote
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    NoteEditorContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel?.hasContent ?? false {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!(viewModel?.isValid ?? false))
                }
            }
            .onAppear {
                if viewModel == nil {
                    let repo = NoteRepository(dbPool: database.dbPool)
                    viewModel = NoteEditorViewModel(
                        repository: repo,
                        speechService: speechService,
                        projectId: projectId,
                        existingNote: existingNote
                    )
                }
                checkPermissions()
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            }
            .alert("Microphone & Speech Recognition Required", isPresented: $showingPermissionAlert) {
                if permissionStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("Grant Access") {
                        requestPermissions()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                if permissionStatus == .denied {
                    Text(
                        "Voice recording requires microphone and speech recognition access. " +
                        "Please enable in Settings."
                    )
                } else {
                    Text(
                        "Voice recording requires microphone and speech recognition access " +
                        "to transcribe your field notes."
                    )
                }
            }
        }
    }

    private func save() {
        guard let viewModel = viewModel else { return }
        do {
            _ = try viewModel.save()
            dismiss()
        } catch {
            // Handle error
        }
    }

    private func checkPermissions() {
        let speechStatus = speechService.authorizationStatus
        if speechStatus != .authorized {
            permissionStatus = speechStatus == .denied ? .denied : .unknown
            showingPermissionAlert = true
        }
    }

    private func requestPermissions() {
        Task {
            let speechGranted = await speechService.requestAuthorization()
            let micGranted = await speechService.requestMicrophoneAuthorization()

            if speechGranted && micGranted {
                permissionStatus = .authorized
            } else {
                permissionStatus = .denied
                showingPermissionAlert = true
            }
        }
    }
}

// MARK: - Content View

private struct NoteEditorContent: View {
    @Bindable var viewModel: NoteEditorViewModel

    var body: some View {
        Form {
            Section("Note Details") {
                TextField("Title", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)

                TextField("Content", text: $viewModel.content, axis: .vertical)
                    .lineLimit(5...15)
            }

            Section("Voice Recording") {
                VoiceRecordingButton(
                    isRecording: viewModel.isRecording,
                    onStart: { viewModel.startRecording() },
                    onStop: { viewModel.stopRecording() }
                )

                if !viewModel.transcription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcription")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.transcription)
                            .font(.body)
                    }
                }

                if viewModel.audioFilePath != nil {
                    Label("Audio recording saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

#Preview {
    NoteEditorView(projectId: 1, existingNote: nil)
}
