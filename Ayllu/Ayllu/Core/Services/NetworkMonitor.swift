import Foundation
import Network
import Observation

/// Monitors network connectivity status
@Observable
final class NetworkMonitor {
    /// Current network connection type
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    /// Current network status
    enum Status {
        case connected(ConnectionType)
        case disconnected

        var isConnected: Bool {
            if case .connected = self {
                return true
            }
            return false
        }

        var displayText: String {
            switch self {
            case .connected(.wifi):
                return "WiFi"
            case .connected(.cellular):
                return "Cellular"
            case .connected(.ethernet):
                return "Ethernet"
            case .connected(.unknown):
                return "Online"
            case .disconnected:
                return "Offline"
            }
        }

        var iconName: String {
            switch self {
            case .connected(.wifi):
                return "wifi"
            case .connected(.cellular):
                return "antenna.radiowaves.left.and.right"
            case .connected(.ethernet):
                return "cable.connector"
            case .connected(.unknown):
                return "network"
            case .disconnected:
                return "wifi.slash"
            }
        }
    }

    /// Current network status
    private(set) var status: Status = .disconnected

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.ayllu.networkmonitor")

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let newStatus: Status
            if path.status == .satisfied {
                let connectionType = self.getConnectionType(from: path)
                newStatus = .connected(connectionType)
            } else {
                newStatus = .disconnected
            }

            // Update on main thread since this is @Observable
            DispatchQueue.main.async {
                self.status = newStatus
            }
        }

        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}
