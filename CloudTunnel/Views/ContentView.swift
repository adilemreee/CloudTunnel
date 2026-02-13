// MARK: - Content View
// Main layout with sidebar navigation

import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject var tunnelService: TunnelService
    @EnvironmentObject var networkService: NetworkService
    
    private var networkIcon: String {
        switch networkService.connectionType {
        case "Wi-Fi":    return "wifi"
        case "Ethernet": return "cable.connector"
        case "Cellular": return "antenna.radiowaves.left.and.right"
        default:         return "network"
        }
    }
    
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
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                toolbarContent
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
        case .docker:
            DockerView()
        case .mamp:
            MAMPView()
        case .fileShare:
            FileShareView()
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
    
    // MARK: - Toolbar
    @ViewBuilder
    var toolbarContent: some View {
        // Network status
        HStack(spacing: 5) {
            Image(systemName: networkService.isConnected ? networkIcon : "wifi.slash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(networkService.isConnected ? CTColors.success : CTColors.danger)
            
            Text(networkService.isConnected ? networkService.connectionType : "Çevrimdışı")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CTColors.textSecondary)
        }
        
        Divider()
        
        // Running tunnels badge
        if tunnelService.totalRunning > 0 {
            HStack(spacing: 4) {
                Circle()
                    .fill(CTColors.success)
                    .frame(width: 7, height: 7)
                Text("\(tunnelService.totalRunning) aktif")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CTColors.success)
            }
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
