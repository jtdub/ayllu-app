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
    }
}

#Preview {
    NetworkStatusIndicator()
        .environment(NetworkMonitor())
}
