import SwiftUI

/// Privacy policy view explaining data ownership and privacy practices
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your data belongs to you")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)

                    // No Data Collection
                    privacySection(
                        title: "No Data Collection",
                        icon: "hand.raised.fill",
                        iconColor: .green
                    ) {
                        Text(
                            """
                            Ayllu does not collect, transmit, or store any of your personal data on external \
                            servers. Everything you create stays on your device.
                            """
                        )
                    }

                    // You Own Your Data
                    privacySection(
                        title: "You Own Your Data",
                        icon: "person.fill",
                        iconColor: .blue
                    ) {
                        Text(
                            """
                            All research data, photos, GPS tracks, field notes, and recordings are stored \
                            locally on your device. You have complete control and ownership of your data.
                            """
                        )
                    }

                    // Local Storage Only
                    privacySection(
                        title: "Local Storage Only",
                        icon: "internaldrive.fill",
                        iconColor: .orange
                    ) {
                        Text(
                            """
                            Your database, photos, audio recordings, and offline maps are stored exclusively \
                            in your device's local storage. No cloud synchronization or external data \
                            transmission occurs.
                            """
                        )
                    }

                    // No Third-Party Tracking
                    privacySection(
                        title: "No Third-Party Tracking",
                        icon: "eye.slash.fill",
                        iconColor: .purple
                    ) {
                        Text(
                            """
                            Ayllu does not use analytics, tracking, or advertising services. We do not share \
                            your data with third parties because we never have access to it in the first place.
                            """
                        )
                    }

                    // Offline-First Design
                    privacySection(
                        title: "Offline-First Design",
                        icon: "airplane",
                        iconColor: .indigo
                    ) {
                        Text(
                            """
                            The app is designed to work completely offline. Network access is only used for \
                            downloading open-source map tiles when you explicitly request them.
                            """
                        )
                    }

                    // Device Permissions
                    privacySection(
                        title: "Device Permissions",
                        icon: "shield.fill",
                        iconColor: .cyan
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ayllu requests the following permissions to provide core functionality:")

                            permissionItem(
                                icon: "location.fill",
                                text: "Location - For GPS waypoints and track recording"
                            )
                            permissionItem(
                                icon: "camera.fill",
                                text: "Camera - For geotagged field photography"
                            )
                            permissionItem(
                                icon: "mic.fill",
                                text: "Microphone - For voice note recording"
                            )
                            permissionItem(
                                icon: "waveform",
                                text: "Speech Recognition - For offline voice-to-text transcription"
                            )

                            Text(
                                """
                                All permissions are used locally on your device. No data is transmitted \
                                externally.
                                """
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                    }

                    // Data Export
                    privacySection(
                        title: "Data Export",
                        icon: "square.and.arrow.up.fill",
                        iconColor: .green
                    ) {
                        Text(
                            """
                            You can export your data at any time using the backup feature or GPX export. \
                            Exported data remains under your complete control and can be used with other tools \
                            or archived as you see fit.
                            """
                        )
                    }

                    // Contact
                    privacySection(
                        title: "Questions?",
                        icon: "questionmark.circle.fill",
                        iconColor: .gray
                    ) {
                        Text(
                            """
                            If you have questions about privacy or data handling, please open an issue on our \
                            GitHub feedback repository.
                            """
                        )
                    }

                    Text("Last updated: February 2026")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func privacySection(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)

                Text(title)
                    .font(.headline)
            }

            content()
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.leading, 44)
        }
    }

    @ViewBuilder
    private func permissionItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
