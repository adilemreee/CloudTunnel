// MARK: - Sidebar View
// Professional sidebar with sections, icons, and badges

import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem
    @EnvironmentObject var tunnelService: TunnelService
    @EnvironmentObject var dockerService: DockerService
    @EnvironmentObject var historyService: HistoryService
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header
            appHeader
                .padding(.horizontal, CTSpacing.lg)
                .padding(.top, CTSpacing.lg)
                .padding(.bottom, CTSpacing.md)
            
            Divider()
                .padding(.horizontal, CTSpacing.lg)
            
            // Navigation Items
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: CTSpacing.xs) {
                    ForEach(NavigationItem.NavigationSection.allCases, id: \.self) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, CTSpacing.md)
                .padding(.vertical, CTSpacing.md)
            }
            
            Spacer()
            
            // Bottom Status
            bottomStatus
                .padding(CTSpacing.lg)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - App Header
    var appHeader: some View {
        HStack(spacing: 10) {
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CTColors.brandGradient)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "cloud.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("CloudTunnel")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("v1.0.0")
                    .font(CTTypography.caption)
                    .foregroundStyle(CTColors.textTertiary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Section View
    @ViewBuilder
    func sectionView(_ section: NavigationItem.NavigationSection) -> some View {
        let items = NavigationItem.allCases.filter { $0.section == section }
        
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                if !section.title.isEmpty {
                    Text(section.title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CTColors.textTertiary)
                        .padding(.horizontal, CTSpacing.sm)
                        .padding(.top, CTSpacing.md)
                        .padding(.bottom, CTSpacing.xs)
                }
                
                ForEach(items) { item in
                    sidebarButton(item)
                }
            }
        }
    }
    
    // MARK: - Sidebar Button
    func sidebarButton(_ item: NavigationItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedItem = item
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: selectedItem == item ? .semibold : .regular))
                    .foregroundStyle(selectedItem == item ? CTColors.brand : CTColors.textSecondary)
                    .frame(width: 20)
                
                Text(item.title)
                    .font(.system(size: 13, weight: selectedItem == item ? .semibold : .regular))
                    .foregroundStyle(selectedItem == item ? CTColors.textPrimary : CTColors.textSecondary)
                
                Spacer()
                
                // Badges
                badge(for: item)
            }
            .padding(.horizontal, CTSpacing.sm)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                    .fill(selectedItem == item ? CTColors.sidebarSelected : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Badge
    @ViewBuilder
    func badge(for item: NavigationItem) -> some View {
        switch item {
        case .tunnels:
            if tunnelService.runningManagedCount > 0 {
                badgeView("\(tunnelService.runningManagedCount)", color: CTColors.success)
            }
        case .quickTunnel:
            if tunnelService.runningQuickCount > 0 {
                badgeView("\(tunnelService.runningQuickCount)", color: CTColors.brand)
            }
        case .docker:
            if dockerService.isDockerRunning {
                badgeView("\(dockerService.runningContainers.count)", color: CTColors.info)
            }
        case .history:
            if historyService.errorCount > 0 {
                badgeView("\(historyService.errorCount)", color: CTColors.danger)
            }
        default:
            EmptyView()
        }
    }
    
    func badgeView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
    
    // MARK: - Bottom Status
    var bottomStatus: some View {
        VStack(spacing: CTSpacing.sm) {
            Divider()
            
            HStack(spacing: CTSpacing.sm) {
                Circle()
                    .fill(tunnelService.cloudflaredInstalled ? CTColors.success : CTColors.danger)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("cloudflared")
                        .font(CTTypography.captionBold)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text(tunnelService.cloudflaredInstalled
                         ? (tunnelService.cloudflaredVersion ?? "Installed")
                         : "Not Found")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                }
                
                Spacer()
            }
        }
    }
}
