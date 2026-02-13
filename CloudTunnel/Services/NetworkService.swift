// MARK: - Network Service
// Monitors network connectivity using NWPathMonitor

import Foundation
import Network

@MainActor
final class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    @Published var isConnected = true
    @Published var connectionType: String = "Unknown"
    @Published var interfaceName: String?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.cloudtunnel.network")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = "Wi-Fi"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = "Ethernet"
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = "Cellular"
                } else {
                    self?.connectionType = path.status == .satisfied ? "Connected" : "Disconnected"
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
