// MARK: - Content View
// Main layout with sidebar navigation

import SwiftUI

struct ContentView: View {
    @State private var selectedItem: NavigationItem = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject var tunnelService: TunnelService
    @EnvironmentObject var networkService: NetworkService
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedItem)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
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
        HStack(spacing: 6) {
            Circle()
                .fill(networkService.isConnected ? CTColors.success : CTColors.danger)
                .frame(width: 8, height: 8)
            
            Text(networkService.isConnected ? networkService.connectionType : "Offline")
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
        
        Divider()
        
        // Running tunnels badge
        if tunnelService.totalRunning > 0 {
            HStack(spacing: 4) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(CTColors.success)
                Text("\(tunnelService.totalRunning) active")
                    .font(CTTypography.captionBold)
                    .foregroundStyle(CTColors.success)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(CTColors.success.opacity(0.1))
            .clipShape(Capsule())
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
