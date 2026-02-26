import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @Environment(DatabaseManager.self) private var database

    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormatter.Format = .decimal
    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters
    @AppStorage("useTrueNorth") private var useTrueNorth = false
    @AppStorage("colorScheme") private var colorScheme: ColorSchemePreference = .system

    @State private var databaseSize: String = "—"
    @State private var offlineMapSize: String = "—"
    @State private var showingClearConfirmation = false
    @State private var showingBackupManager = false
    @State private var backupService: DatabaseBackupService?
    @State private var showingTrash = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color Scheme", selection: $colorScheme) {
                    ForEach(ColorSchemePreference.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                Text("Choose between light, dark, or automatic appearance based on system settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Coordinates") {
                Picker("Format", selection: $coordinateFormat) {
                    ForEach(CoordinateFormatter.Format.allCases, id: \.self) { format in
                        VStack(alignment: .leading) {
                            Text(format.displayName)
                            Text(format.example)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(format)
                    }
                }
            }

            Section("Units") {
                Picker("Distance", selection: $distanceUnit) {
                    ForEach(CoordinateFormatter.DistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            }

            Section("Compass") {
                Toggle("Use True North", isOn: $useTrueNorth)
                Text("When enabled, headings are displayed relative to true north instead of magnetic north.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                LabeledContent("Database Size", value: databaseSize)

                LabeledContent("Offline Maps", value: offlineMapSize)

                Button {
                    showingTrash = true
                } label: {
                    Label("Recently Deleted", systemImage: "trash")
                }

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear Offline Maps", systemImage: "trash.slash")
                }
            }

            Section("Backup & Restore") {
                if let service = backupService, let lastBackup = service.lastBackupDate {
                    LabeledContent("Last Backup") {
                        Text(lastBackup, style: .relative) + Text(" ago")
                    }
                } else {
                    LabeledContent("Last Backup", value: "Never")
                }

                Button {
                    showingBackupManager = true
                } label: {
                    Label("Manage Backups", systemImage: "internaldrive")
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)

                Link(destination: URL(string: "https://github.com/jtdub/ayllu-feedback/issues")!) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingBackupManager) {
            if let service = backupService {
                BackupManagerView(backupService: service)
            }
        }
        .sheet(isPresented: $showingTrash) {
            TrashView()
        }
        .onAppear {
            loadStorageInfo()
            if backupService == nil {
                backupService = DatabaseBackupService(databaseManager: database)
            }
        }
        .alert("Clear Offline Maps?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearOfflineMaps()
            }
        } message: {
            Text("This will delete all downloaded map tiles. You will need to re-download maps for offline use.")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func loadStorageInfo() {
        databaseSize = database.formattedDatabaseSize()

        let repo = MapRegionRepository(dbPool: database.dbPool)
        offlineMapSize = (try? repo.formattedStorageUsed()) ?? "—"
    }

    private func clearOfflineMaps() {
        let repo = MapRegionRepository(dbPool: database.dbPool)
        let regions = (try? repo.fetchAll()) ?? []
        for region in regions {
            try? repo.delete(region)
        }
        loadStorageInfo()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
