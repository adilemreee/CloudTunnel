// MARK: - Dashboard View
// Beautiful overview with stats, status, and quick actions

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @EnvironmentObject var dockerService: DockerService
    @EnvironmentObject var mampService: MAMPService
    @EnvironmentObject var networkService: NetworkService
    @EnvironmentObject var historyService: HistoryService
    @EnvironmentObject var fileShareService: FileShareService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                // Header
                header
                
                // Stats Grid
                statsGrid
                
                // Environment & Quick Actions
                HStack(alignment: .top, spacing: CTSpacing.lg) {
                    environmentStatus
                    quickActions
                }
                
                // Active Tunnels
                activeTunnels
                
                // Recent Activity
                recentActivity
            }
            .padding(CTSpacing.xxl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("dashboard.title", comment: ""))
                    .font(CTTypography.largeTitle)
                    .foregroundStyle(CTColors.textPrimary)
                
                Text(NSLocalizedString("dashboard.subtitle", comment: ""))
                    .font(CTTypography.body)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
            
            // Refresh button
            Button {
                tunnelService.scanConfigFiles()
                dockerService.refreshContainers()
                mampService.scanSites()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CTColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Stats Grid
    var statsGrid: some View {
        HStack(spacing: CTSpacing.lg) {
            // Managed Tunnels
            StatCard(
                title: NSLocalizedString("stats.managed", comment: ""),
                value: "\(tunnelService.managedTunnels.count)",
                subtitle: "\(tunnelService.runningManagedCount) " + NSLocalizedString("stats.active", comment: ""),
                icon: "point.3.connected.trianglepath.dotted",
                gradient: CTColors.brandGradient
            )
            
            // Quick Tunnels
            StatCard(
                title: NSLocalizedString("stats.quick", comment: ""),
                value: "\(tunnelService.quickTunnels.count)",
                subtitle: NSLocalizedString("stats.temporary", comment: ""),
                icon: "bolt.horizontal",
                gradient: CTColors.coolGradient
            )
            
            // Docker Containers
            StatCard(
                title: "Docker",
                value: "\(dockerService.runningContainers.count)",
                subtitle: "\(dockerService.containers.count) " + NSLocalizedString("stats.total", comment: ""),
                icon: "shippingbox",
                gradient: CTColors.successGradient
            )
            
            // Errors
            StatCard(
                title: NSLocalizedString("stats.errors", comment: ""),
                value: "\(tunnelService.errorCount)",
                subtitle: NSLocalizedString("stats.needsAttention", comment: ""),
                icon: "exclamationmark.triangle",
                gradient: tunnelService.errorCount > 0 ? CTColors.dangerGradient : CTColors.warmGradient
            )
        }
    }
    
    // MARK: - Environment Status
    var environmentStatus: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(title: NSLocalizedString("dashboard.environment", comment: ""))
            
            VStack(spacing: CTSpacing.sm) {
                EnvironmentRow(
                    name: "cloudflared",
                    status: tunnelService.cloudflaredInstalled,
                    detail: tunnelService.cloudflaredVersion ?? "—",
                    icon: "cloud"
                )
                
                EnvironmentRow(
                    name: "Docker",
                    status: dockerService.isDockerRunning,
                    detail: dockerService.dockerVersion ?? (dockerService.isDockerInstalled ? "Stopped" : "Not Installed"),
                    icon: "shippingbox"
                )
                
                EnvironmentRow(
                    name: "MAMP",
                    status: mampService.isMAMPRunning,
                    detail: mampService.isMAMPInstalled ? (mampService.isMAMPRunning ? "Running" : "Stopped") : "Not Installed",
                    icon: "server.rack"
                )
                
                EnvironmentRow(
                    name: NSLocalizedString("dashboard.network", comment: ""),
                    status: networkService.isConnected,
                    detail: networkService.connectionType,
                    icon: "wifi"
                )
                
                EnvironmentRow(
                    name: NSLocalizedString("dashboard.fileShare", comment: ""),
                    status: fileShareService.isSharing,
                    detail: fileShareService.isSharing ? "Active" : "Inactive",
                    icon: "folder.badge.person.crop"
                )
            }
        }
        .ctCard()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Actions
    var quickActions: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(title: NSLocalizedString("dashboard.quickActions", comment: ""))
            
            VStack(spacing: CTSpacing.sm) {
                QuickActionButton(
                    title: NSLocalizedString("action.startAll", comment: ""),
                    icon: "play.fill",
                    color: CTColors.success
                ) {
                    Task { await tunnelService.startAllTunnels() }
                }
                
                QuickActionButton(
                    title: NSLocalizedString("action.stopAll", comment: ""),
                    icon: "stop.fill",
                    color: CTColors.danger
                ) {
                    Task { await tunnelService.stopAllTunnels() }
                }
                
                QuickActionButton(
                    title: NSLocalizedString("action.rescan", comment: ""),
                    icon: "arrow.clockwise",
                    color: CTColors.brand
                ) {
                    tunnelService.scanConfigFiles()
                }
                
                if dockerService.isDockerRunning {
                    QuickActionButton(
                        title: NSLocalizedString("action.refreshDocker", comment: ""),
                        icon: "arrow.triangle.2.circlepath",
                        color: CTColors.info
                    ) {
                        dockerService.refreshContainers()
                    }
                }
                
                if mampService.isMAMPInstalled {
                    QuickActionButton(
                        title: mampService.isMAMPRunning
                            ? NSLocalizedString("action.stopMAMP", comment: "")
                            : NSLocalizedString("action.startMAMP", comment: ""),
                        icon: mampService.isMAMPRunning ? "stop.circle" : "play.circle",
                        color: CTColors.warning
                    ) {
                        Task {
                            if mampService.isMAMPRunning {
                                await mampService.stopMAMP()
                            } else {
                                await mampService.startMAMP()
                            }
                        }
                    }
                }
            }
        }
        .ctCard()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Active Tunnels
    @ViewBuilder
    var activeTunnels: some View {
        let running = tunnelService.managedTunnels.filter { $0.status == .running }
        
        if !running.isEmpty {
            VStack(alignment: .leading, spacing: CTSpacing.md) {
                CTSectionHeader(
                    title: NSLocalizedString("dashboard.activeTunnels", comment: ""),
                    subtitle: "\(running.count) " + NSLocalizedString("dashboard.running", comment: "")
                )
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: CTSpacing.md) {
                    ForEach(running) { tunnel in
                        ActiveTunnelCard(tunnel: tunnel)
                    }
                }
            }
            .ctCard()
        }
    }
    
    // MARK: - Recent Activity
    var recentActivity: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(
                title: NSLocalizedString("dashboard.recentActivity", comment: ""),
                subtitle: "\(historyService.todayCount) " + NSLocalizedString("dashboard.today", comment: "")
            )
            
            if historyService.logs.isEmpty {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("dashboard.noActivity", comment: ""))
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textTertiary)
                        .padding(.vertical, CTSpacing.xl)
                    Spacer()
                }
            } else {
                VStack(spacing: 2) {
                    ForEach(historyService.logs.prefix(5)) { entry in
                        ActivityRow(entry: entry)
                    }
                }
            }
        }
        .ctCard()
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    
    var body: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            
            Text(title)
                .font(CTTypography.headline)
                .opacity(0.9)
            
            Text(subtitle)
                .font(CTTypography.caption)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .ctStatCard(gradient)
    }
}

// MARK: - Environment Row
struct EnvironmentRow: View {
    let name: String
    let status: Bool
    let detail: String
    let icon: String
    
    var body: some View {
        HStack(spacing: CTSpacing.md) {
            CTIconBadge(icon: icon, color: status ? CTColors.success : CTColors.textTertiary, size: 32)
            
            Text(name)
                .font(CTTypography.headline)
                .foregroundStyle(CTColors.textPrimary)
            
            Spacer()
            
            Text(detail)
                .font(CTTypography.callout)
                .foregroundStyle(CTColors.textSecondary)
            
            Circle()
                .fill(status ? CTColors.success : CTColors.textTertiary)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: CTSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                Text(title)
                    .font(CTTypography.headline)
                    .foregroundStyle(CTColors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CTColors.textTertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Active Tunnel Card
struct ActiveTunnelCard: View {
    let tunnel: ManagedTunnel
    @EnvironmentObject var tunnelService: TunnelService
    
    var body: some View {
        HStack(spacing: CTSpacing.md) {
            CTIconBadge(icon: tunnel.tunnelProtocol.icon, color: CTColors.success, size: 36)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(tunnel.displayName)
                    .font(CTTypography.headline)
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("\(tunnel.hostname.isEmpty ? "localhost" : tunnel.hostname):\(tunnel.port)")
                    .font(CTTypography.monoSmall)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
            
            Button {
                Task { await tunnelService.stopTunnel(tunnel) }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(CTColors.danger)
                    .frame(width: 26, height: 26)
                    .background(CTColors.danger.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(CTSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(CTColors.success.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(CTColors.success.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(spacing: CTSpacing.md) {
            Image(systemName: entry.level.icon)
                .font(.system(size: 11))
                .foregroundStyle(entry.level.color)
                .frame(width: 20)
            
            Text(entry.message)
                .font(CTTypography.callout)
                .foregroundStyle(CTColors.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            Text(entry.timestamp, style: .relative)
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textTertiary)
        }
        .padding(.vertical, 6)
    }
}
