import Foundation
import GRDB

/// Service for backing up and restoring the database
@Observable
final class DatabaseBackupService {
    // MARK: - Properties

    private let databaseManager: DatabaseManager
    private let fileManager = FileManager.default
    private let maxBackupCount = 3

    /// Last backup timestamp
    private(set) var lastBackupDate: Date?

    /// Available backups sorted by date (newest first)
    private(set) var availableBackups: [BackupInfo] = []

    // MARK: - Initialization

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        loadBackupInfo()
    }

    // MARK: - Backup Directory

    private var backupsDirectory: URL {
        get throws {
            let documentsURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let backupsURL = documentsURL.appendingPathComponent("Backups", isDirectory: true)

            // Create backups directory if needed
            if !fileManager.fileExists(atPath: backupsURL.path) {
                try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
            }

            return backupsURL
        }
    }

    // MARK: - Create Backup

    /// Creates a backup of the current database
    /// - Returns: The backup file URL
    /// - Throws: Error if backup fails
    func createBackup() throws -> URL {
        // Checkpoint WAL to ensure all data is in the main database file
        try databaseManager.dbPool.writeWithoutTransaction { db in
            try db.checkpoint(.passive)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupName = "ayllu-backup-\(timestamp).sqlite"
        let backupURL = try backupsDirectory.appendingPathComponent(backupName)

        // Copy database file
        let databaseURL = URL(fileURLWithPath: databaseManager.databasePath)
        try fileManager.copyItem(at: databaseURL, to: backupURL)

        // Update last backup date
        lastBackupDate = Date()
        UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupDate")

        // Cleanup old backups
        try cleanupOldBackups()

        // Reload backup list
        loadBackupInfo()

        return backupURL
    }

    // MARK: - Restore Backup

    /// Restores the database from a backup file
    /// - Parameter backupURL: The backup file URL to restore from
    /// - Throws: Error if restore fails
    func restoreBackup(from backupURL: URL) throws {
        // Verify backup file exists and is readable
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw BackupError.backupNotFound
        }

        // Verify backup is a valid SQLite database
        guard try isValidSQLiteDatabase(at: backupURL) else {
            throw BackupError.invalidBackup
        }

        // Close current database connection
        // Note: GRDB's DatabasePool doesn't have a close method, so we'll replace the file
        let databaseURL = URL(fileURLWithPath: databaseManager.databasePath)

        // Remove existing database files
        try? fileManager.removeItem(at: databaseURL)
        let walURL = databaseURL.appendingPathExtension("wal")
        let shmURL = databaseURL.appendingPathExtension("shm")
        try? fileManager.removeItem(at: walURL)
        try? fileManager.removeItem(at: shmURL)

        // Copy backup to database location
        try fileManager.copyItem(at: backupURL, to: databaseURL)
    }

    // MARK: - Export/Import

    /// Exports a backup to the Files app
    /// - Parameter backupInfo: The backup to export
    /// - Returns: URL for sharing via UIActivityViewController
    func prepareBackupForExport(_ backupInfo: BackupInfo) -> URL {
        return backupInfo.url
    }

    /// Imports a backup from an external source
    /// - Parameter sourceURL: The external backup file URL
    /// - Returns: The imported backup info
    /// - Throws: Error if import fails
    func importBackup(from sourceURL: URL) throws -> BackupInfo {
        // Ensure we have access to the file
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw BackupError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        // Verify it's a valid database
        guard try isValidSQLiteDatabase(at: sourceURL) else {
            throw BackupError.invalidBackup
        }

        // Copy to backups directory
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupName = "ayllu-imported-\(timestamp).sqlite"
        let destinationURL = try backupsDirectory.appendingPathComponent(backupName)

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        // Reload backup list
        loadBackupInfo()

        // Return the new backup info
        guard let backupInfo = availableBackups.first(where: { $0.url == destinationURL }) else {
            throw BackupError.importFailed
        }

        return backupInfo
    }

    // MARK: - Delete Backup

    /// Deletes a specific backup
    /// - Parameter backupInfo: The backup to delete
    /// - Throws: Error if deletion fails
    func deleteBackup(_ backupInfo: BackupInfo) throws {
        try fileManager.removeItem(at: backupInfo.url)
        loadBackupInfo()
    }

    // MARK: - Private Methods

    private func loadBackupInfo() {
        // Load last backup date from UserDefaults
        lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date

        // Scan backups directory
        guard let backupsURL = try? backupsDirectory else {
            availableBackups = []
            return
        }

        guard let files = try? fileManager.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        ) else {
            availableBackups = []
            return
        }

        // Filter for .sqlite files and create BackupInfo
        availableBackups = files
            .filter { $0.pathExtension == "sqlite" }
            .compactMap { url -> BackupInfo? in
                guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                      let creationDate = attributes[.creationDate] as? Date,
                      let size = attributes[.size] as? Int64 else {
                    return nil
                }
                return BackupInfo(url: url, createdAt: creationDate, size: size)
            }
            .sorted { $0.createdAt > $1.createdAt }  // Newest first
    }

    private func cleanupOldBackups() throws {
        let backupsToDelete = availableBackups.dropFirst(maxBackupCount)
        for backup in backupsToDelete {
            try? fileManager.removeItem(at: backup.url)
        }
    }

    private func isValidSQLiteDatabase(at url: URL) throws -> Bool {
        // Try to open the database to verify it's valid
        do {
            let queue = try DatabaseQueue(path: url.path)
            _ = try queue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master")
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Backup Info

struct BackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let createdAt: Date
    let size: Int64

    var fileName: String {
        url.lastPathComponent
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case backupNotFound
    case invalidBackup
    case accessDenied
    case importFailed

    var errorDescription: String? {
        switch self {
        case .backupNotFound:
            return "Backup file not found"
        case .invalidBackup:
            return "Invalid backup file. The file may be corrupted or not a valid Ayllu backup."
        case .accessDenied:
            return "Cannot access backup file. Please grant permission."
        case .importFailed:
            return "Failed to import backup file"
        }
    }
}
