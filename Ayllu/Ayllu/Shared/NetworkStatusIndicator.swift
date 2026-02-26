import SwiftUI

/// Displays current network connectivity status
struct NetworkStatusIndicator: View {
    @Environment(NetworkMonitor.self) private var networkMonitor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: networkMonitor.status.iconName)
                .font(.caption)

            Text(networkMonitor.status.displayText)
                .font(.caption2)
        }
        .foregroundColor(networkMonitor.status.isConnected ? .secondary : .orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(networkMonitor.status.isConnected
                    ? Color.secondary.opacity(0.1)
                    : Color.orange.opacity(0.15))
        )
    }
}

#Preview {
    NetworkStatusIndicator()
        .environment(NetworkMonitor())
}
