import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// View for managing database backups
struct BackupManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var backupService: DatabaseBackupService

    @State private var isCreatingBackup = false
    @State private var isRestoringBackup = false
    @State private var showingRestoreConfirmation = false
    @State private var selectedBackup: BackupInfo?
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var showingImportPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        createBackup()
                    } label: {
                        Label("Create Backup Now", systemImage: "plus.circle.fill")
                    }
                    .disabled(isCreatingBackup)

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                }

                if !backupService.availableBackups.isEmpty {
                    Section("Available Backups") {
                        ForEach(backupService.availableBackups) { backup in
                            BackupRow(backup: backup)
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteBackup(backup)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        shareBackup(backup)
                                    } label: {
                                        Label("Export", systemImage: "square.and.arrow.up")
                                    }
                                    .tint(.blue)

                                    Button {
                                        selectedBackup = backup
                                        showingRestoreConfirmation = true
                                    } label: {
                                        Label("Restore", systemImage: "arrow.counterclockwise")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "No Backups",
                            systemImage: "internaldrive",
                            description: Text("Create your first backup to protect your field data")
                        )
                    }
                }

                Section {
                    Text("""
                        Backups are stored locally on your device. \
                        Export backups to iCloud or Files app for safekeeping.
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Backup & Restore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Restore Backup?", isPresented: $showingRestoreConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restore", role: .destructive) {
                    if let backup = selectedBackup {
                        restoreBackup(backup)
                    }
                }
            } message: {
                Text("This will replace your current database with the backup. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.database],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .overlay {
                if isCreatingBackup || isRestoringBackup {
                    ProgressView(isCreatingBackup ? "Creating backup..." : "Restoring backup...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Actions

    private func createBackup() {
        isCreatingBackup = true
        Task {
            do {
                _ = try backupService.createBackup()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isCreatingBackup = false
        }
    }

    private func restoreBackup(_ backup: BackupInfo) {
        isRestoringBackup = true
        Task {
            do {
                try backupService.restoreBackup(from: backup.url)
                // Note: App needs to restart after restore for changes to take effect
                errorMessage = "Backup restored successfully. Please restart the app."
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isRestoringBackup = false
        }
    }

    private func deleteBackup(_ backup: BackupInfo) {
        do {
            try backupService.deleteBackup(backup)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func shareBackup(_ backup: BackupInfo) {
        shareURL = backupService.prepareBackupForExport(backup)
        showingShareSheet = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    _ = try backupService.importBackup(from: url)
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Backup Row

struct BackupRow: View {
    let backup: BackupInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(backup.formattedDate)
                    .font(.headline)
                Spacer()
                Text(backup.formattedSize)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(backup.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - UTType Extension

extension UTType {
    static let database = UTType(filenameExtension: "sqlite")!
}

#Preview {
    if let db = try? DatabaseManager.inMemory() {
        BackupManagerView(backupService: DatabaseBackupService(databaseManager: db))
    } else {
        Text("Preview unavailable")
    }
}
