// MARK: - CloudTunnel App
// Modern windowed macOS application for Cloudflare tunnel management

import SwiftUI
import ServiceManagement

@main
struct CloudTunnelApp: App {
    @StateObject private var tunnelService = TunnelService.shared
    @StateObject private var dockerService = DockerService.shared
    @StateObject private var mampService = MAMPService.shared
    @StateObject private var fileShareService = FileShareService.shared
    @StateObject private var networkService = NetworkService.shared
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var backupService = BackupService.shared
    @StateObject private var shortcutManager = KeyboardShortcutManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tunnelService)
                .environmentObject(dockerService)
                .environmentObject(mampService)
                .environmentObject(fileShareService)
                .environmentObject(networkService)
                .environmentObject(historyService)
                .environmentObject(backupService)
                .frame(minWidth: 960, minHeight: 640)
                .background(Color(nsColor: .windowBackgroundColor))
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                        NotificationHelper.requestPermission()
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1120, height: 720)
        
        Settings {
            SettingsView()
                .environmentObject(tunnelService)
                .environmentObject(mampService)
                .environmentObject(backupService)
                .environmentObject(historyService)
                .frame(minWidth: 600, minHeight: 450)
        }
    }
}
