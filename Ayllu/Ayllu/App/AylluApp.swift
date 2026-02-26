import SwiftUI

@main
struct AylluApp: App {
    @AppStorage("colorScheme") private var colorScheme: ColorSchemePreference = .system
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var databaseManager: DatabaseManager?
    @State private var locationService = LocationService()
    @State private var speechService = SpeechService()
    @State private var networkMonitor = NetworkMonitor()
    @State private var initializationError: Error?
    @State private var showingOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let database = databaseManager {
                    TabBarView()
                        .environment(database)
                        .environment(locationService)
                        .environment(speechService)
                        .environment(networkMonitor)
                        .sheet(isPresented: $showingOnboarding) {
                            OnboardingView()
                        }
                        .onAppear {
                            if !hasCompletedOnboarding {
                                showingOnboarding = true
                            }
                        }
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
            .preferredColorScheme(colorScheme.colorScheme)
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
