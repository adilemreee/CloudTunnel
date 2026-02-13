// MARK: - Content View
// Main layout with sidebar navigation

import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject var tunnelService: TunnelService
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedItem)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .withTouchBar()
        .onReceive(NotificationCenter.default.publisher(for: .navigateToQuickTunnel)) { _ in
            selectedItem = .quickTunnel
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToItem)) { notification in
            if let item = notification.object as? NavigationItem {
                selectedItem = item
            }
        }
    }
    
    // MARK: - Detail View Router
    @ViewBuilder
    var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .tunnels:
            TunnelListView()
        case .quickTunnel:
            QuickTunnelView()
        case .portScanner:
            PortScannerView()
        case .docker:
            DockerView()
        case .mamp:
            MAMPView()
        case .fileShare:
            FileShareView()
        case .liveLog:
            LiveLogView()
        case .qrCode:
            QRCodeView()
        case .domainMigration:
            DomainMigrationView()
        case .teamSharing:
            TeamSharingView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TunnelService.shared)
        .environmentObject(DockerService.shared)
        .environmentObject(MAMPService.shared)
        .environmentObject(FileShareService.shared)
        .environmentObject(NetworkService.shared)
        .environmentObject(HistoryService.shared)
        .environmentObject(BackupService.shared)
}
