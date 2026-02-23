import SwiftUI

@main
struct AylluApp: App {
    @State private var databaseManager: DatabaseManager?
    @State private var locationService = LocationService()
    @State private var speechService = SpeechService()
    @State private var initializationError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if let database = databaseManager {
                    TabBarView()
                        .environment(database)
                        .environment(locationService)
                        .environment(speechService)
                } else if let error = initializationError {
                    ErrorView(error: error) {
                        initializeDatabase()
                    }
                } else {
                    ProgressView("Initializing...")
                        .task {
                            initializeDatabase()
                        }
                }
            }
        }
    }

    private func initializeDatabase() {
        do {
            databaseManager = try DatabaseManager()
            initializationError = nil
        } catch {
            initializationError = error
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Database Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
