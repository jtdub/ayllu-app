import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @Environment(DatabaseManager.self) private var database

    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormatter.Format = .decimal
    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters

    @State private var databaseSize: String = "—"
    @State private var offlineMapSize: String = "—"
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
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

            Section("Storage") {
                LabeledContent("Database Size", value: databaseSize)

                LabeledContent("Offline Maps", value: offlineMapSize)

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear Offline Maps", systemImage: "trash")
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)

                Link(destination: URL(string: "https://github.com/jtdub/ayllu-app")!) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: URL(string: "https://github.com/jtdub/ayllu-app/issues")!) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            loadStorageInfo()
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
