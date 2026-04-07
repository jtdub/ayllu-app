import SwiftUI

/// Onboarding flow for first-time users
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormatter.Format = .decimal

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Ayllu",
            systemImage: "map.fill",
            description: """
                Your complete field research companion for archaeology, anthropology, and ecological fieldwork.
                """,
            features: [
                "Record GPS waypoints with precision",
                "Capture geotagged photos",
                "Take field notes with voice-to-text",
                "Work completely offline"
            ]
        ),
        OnboardingPage(
            title: "Location Services",
            systemImage: "location.fill",
            description: """
                Ayllu needs location access to record accurate GPS coordinates for your waypoints and photos.
                """,
            features: [
                "High-precision GPS recording",
                "Multiple coordinate formats",
                "Altitude and accuracy tracking",
                "Background tracking for trails"
            ]
        ),
        OnboardingPage(
            title: "Camera Access",
            systemImage: "camera.fill",
            description: "Take geotagged photos directly within the app to document your findings.",
            features: [
                "Automatic GPS tagging",
                "Photo metadata preservation",
                "Location indicator overlay",
                "Link photos to waypoints"
            ]
        ),
        OnboardingPage(
            title: "Microphone Access",
            systemImage: "mic.fill",
            description: "Use voice-to-text for hands-free note taking in the field.",
            features: [
                "On-device speech recognition",
                "Works completely offline",
                "Instant transcription",
                "Edit after recording"
            ]
        ),
        OnboardingPage(
            title: "Choose Your Coordinate Format",
            systemImage: "globe",
            description: "Select your preferred coordinate format. You can change this anytime in Settings.",
            features: [],
            showsCoordinatePicker: true
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index], coordinateFormat: $coordinateFormat)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator and navigation
            VStack(spacing: 20) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("onboardingNextButton")
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("onboardingGetStartedButton")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .interactiveDismissDisabled()
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let title: String
    let systemImage: String
    let description: String
    let features: [String]
    var showsCoordinatePicker: Bool = false
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var coordinateFormat: CoordinateFormatter.Format

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                // Icon
                Image(systemName: page.systemImage)
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)
                    .padding(.bottom, 8)

                // Title
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Description
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Features or coordinate picker
                if page.showsCoordinatePicker {
                    VStack(spacing: 16) {
                        ForEach(CoordinateFormatter.Format.allCases, id: \.self) { format in
                            Button {
                                coordinateFormat = format
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(format.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(format.example)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if coordinateFormat == format {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(coordinateFormat == format
                                            ? Color.accentColor.opacity(0.1)
                                            : Color.secondary.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                } else if !page.features.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(page.features, id: \.self) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.body)
                                Text(feature)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    OnboardingView()
}
