// MARK: - Menu Bar Popover View
// Modern compact control center for CloudTunnel

import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @EnvironmentObject var mampService: MAMPService
    @Environment(\.openWindow) private var openWindow
    
    private var favoriteManagedTunnels: [ManagedTunnel] {
        tunnelService.favoriteTunnels.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
    
    private var otherManagedTunnels: [ManagedTunnel] {
        tunnelService.managedTunnels
            .filter { !$0.isFavorite }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    private var managedRunningCount: Int {
        otherManagedTunnels.filter { $0.status == .running }.count
    }
    
    private var favoriteRunningCount: Int {
        favoriteManagedTunnels.filter { $0.status == .running }.count
    }
    
    private var quickRunningCount: Int {
        tunnelService.quickTunnels.filter { $0.status == .running }.count
    }
    
    private var hasAnyTunnel: Bool {
        !tunnelService.managedTunnels.isEmpty || !tunnelService.quickTunnels.isEmpty
    }
    
    private var isMAMPActionDisabled: Bool {
        !mampService.isMAMPInstalled || mampService.isStarting || mampService.isStopping
    }
    
    private var mampActionTitle: String {
        if !mampService.isMAMPInstalled {
            return "MAMP Yok"
        }
        if mampService.isStarting {
            return "Açılıyor..."
        }
        if mampService.isStopping {
            return "Kapanıyor..."
        }
        return mampService.isMAMPRunning ? "MAMP Kapat" : "MAMP Aç"
    }
    
    private var mampActionIcon: String {
        if mampService.isStarting || mampService.isStopping {
            return "hourglass"
        }
        return mampService.isMAMPRunning ? "power" : "server.rack"
    }
    
    private var mampActionTint: Color {
        if !mampService.isMAMPInstalled {
            return CTColors.textTertiary
        }
        return mampService.isMAMPRunning ? CTColors.warning : CTColors.info
    }
    
    var body: some View {
        VStack(spacing: CTSpacing.md) {
            heroCard
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: CTSpacing.lg) {
                    if !favoriteManagedTunnels.isEmpty {
                        favoritesSection
                    }
                    
                    if !otherManagedTunnels.isEmpty {
                        managedSection
                    }
                    
                    if !tunnelService.quickTunnels.isEmpty {
                        quickSection
                    }
                    
                    if !hasAnyTunnel {
                        emptyState
                    }
                }
                .padding(.horizontal, CTSpacing.xs)
                .padding(.bottom, CTSpacing.xs)
            }
            
            footerBar
        }
        .padding(CTSpacing.md)
        .frame(width: 352, height: 500)
        .background {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Hero
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            HStack(spacing: CTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .fill(CTColors.brandGradient)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CloudTunnel")
                        .font(CTTypography.title3)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text("Hızlı tünel kontrol merkezi")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(tunnelService.cloudflaredInstalled ? CTColors.success : CTColors.danger)
                        .frame(width: 7, height: 7)
                    
                    Text(tunnelService.cloudflaredInstalled ? "Bağlı" : "Bağlantısız")
                        .font(CTTypography.captionBold)
                        .foregroundStyle(tunnelService.cloudflaredInstalled ? CTColors.success : CTColors.danger)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((tunnelService.cloudflaredInstalled ? CTColors.success : CTColors.danger).opacity(0.14))
                .clipShape(Capsule())
            }
            
            HStack(spacing: CTSpacing.sm) {
                MenuBarStatPill(
                    icon: "bolt.fill",
                    value: "\(tunnelService.totalRunning)",
                    label: "Aktif",
                    tint: CTColors.success
                )
                
                MenuBarStatPill(
                    icon: "point.3.connected.trianglepath.dotted",
                    value: "\(tunnelService.managedTunnels.count)",
                    label: "Yönetilen",
                    tint: CTColors.brand
                )
                
                MenuBarStatPill(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(tunnelService.errorCount)",
                    label: "Hata",
                    tint: tunnelService.errorCount > 0 ? CTColors.danger : CTColors.textTertiary
                )
            }
        }
        .padding(CTSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [CTColors.brand.opacity(0.16), CTColors.brand.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                        .stroke(CTColors.brand.opacity(0.22), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Sections
    
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.sm) {
            MenuBarSectionHeader(
                title: "Favoriler",
                subtitle: "\(favoriteRunningCount)/\(favoriteManagedTunnels.count) çalışıyor"
            )
            
            VStack(spacing: CTSpacing.xs) {
                ForEach(favoriteManagedTunnels) { tunnel in
                    MenuBarTunnelRow(tunnel: tunnel, highlightFavorite: true)
                }
            }
        }
    }
    
    private var managedSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.sm) {
            MenuBarSectionHeader(
                title: favoriteManagedTunnels.isEmpty ? "Yönetilen Tüneller" : "Diğer Tüneller",
                subtitle: "\(managedRunningCount)/\(otherManagedTunnels.count) çalışıyor"
            )
            
            VStack(spacing: CTSpacing.xs) {
                ForEach(otherManagedTunnels) { tunnel in
                    MenuBarTunnelRow(tunnel: tunnel)
                }
            }
        }
    }
    
    private var quickSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.sm) {
            MenuBarSectionHeader(
                title: "Quick Tunnels",
                subtitle: "\(quickRunningCount)/\(tunnelService.quickTunnels.count) çalışıyor"
            )
            
            VStack(spacing: CTSpacing.xs) {
                ForEach(tunnelService.quickTunnels) { tunnel in
                    MenuBarQuickTunnelRow(tunnel: tunnel)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: CTSpacing.md) {
            ZStack {
                Circle()
                    .fill(CTColors.brand.opacity(0.12))
                    .frame(width: 66, height: 66)
                
                Image(systemName: "cloud.slash")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(CTColors.brand)
            }
            
            Text("Henüz aktif tünel yok")
                .font(CTTypography.headline)
                .foregroundStyle(CTColors.textPrimary)
            
            Text("Tümünü Başlat ile mevcut tünelleri tek tıkla ayağa kaldırabilir veya ana uygulamadan yeni tünel oluşturabilirsin.")
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CTSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Footer
    
    private var footerBar: some View {
        VStack(spacing: CTSpacing.sm) {
            HStack(spacing: CTSpacing.sm) {
                MenuBarActionButton(
                    title: "Tümünü Başlat",
                    icon: "play.fill",
                    tint: CTColors.success
                ) {
                    Task { await tunnelService.startAllTunnels() }
                }
                
                MenuBarActionButton(
                    title: mampActionTitle,
                    icon: mampActionIcon,
                    tint: mampActionTint,
                    isDisabled: isMAMPActionDisabled
                ) {
                    toggleMAMP()
                }
            }
            
            MenuBarActionButton(
                title: "Uygulamayı Aç",
                icon: "macwindow",
                tint: CTColors.brand
            ) {
                openMainWindow()
            }
        }
        .padding(CTSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first(where: {
            $0.level == .normal && $0.styleMask.contains(.titled)
        }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }
        
        openWindow(id: "main-window")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if let window = NSApp.windows.first(where: {
                $0.level == .normal && $0.styleMask.contains(.titled)
            }) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
    
    private func toggleMAMP() {
        guard !isMAMPActionDisabled else { return }
        Task {
            if mampService.isMAMPRunning {
                await mampService.stopMAMP()
            } else {
                await mampService.startMAMP()
            }
        }
    }
}

// MARK: - Managed Tunnel Row

struct MenuBarTunnelRow: View {
    let tunnel: ManagedTunnel
    var highlightFavorite: Bool = false
    @EnvironmentObject var tunnelService: TunnelService
    @State private var isHovered = false
    
    private var rowTint: Color {
        switch tunnel.status {
        case .running:
            return CTColors.success
        case .error:
            return CTColors.danger
        case .starting, .stopping:
            return CTColors.warning
        case .stopped:
            return CTColors.textTertiary
        }
    }
    
    var body: some View {
        HStack(spacing: CTSpacing.md) {
            CTIconBadge(icon: tunnel.tunnelProtocol.icon, color: rowTint, size: 30)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tunnel.displayName)
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textPrimary)
                        .lineLimit(1)
                    
                    if highlightFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(CTColors.warning)
                    }
                    
                    Text(tunnel.status.displayName)
                        .font(CTTypography.captionBold)
                        .foregroundStyle(rowTint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(rowTint.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text("\(tunnel.hostname.isEmpty ? "localhost" : tunnel.hostname):\(tunnel.port)")
                    .font(CTTypography.monoSmall)
                    .foregroundStyle(CTColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if tunnel.status == .running {
                actionIcon(
                    systemName: "stop.fill",
                    foreground: CTColors.danger,
                    background: CTColors.danger.opacity(0.14)
                ) {
                    Task { await tunnelService.stopTunnel(tunnel) }
                }
            } else if tunnel.status == .stopped || tunnel.status == .error {
                actionIcon(
                    systemName: "play.fill",
                    foreground: CTColors.success,
                    background: CTColors.success.opacity(0.14)
                ) {
                    Task { await tunnelService.startTunnel(tunnel) }
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 26, height: 26)
            }
        }
        .padding(.horizontal, CTSpacing.md)
        .padding(.vertical, CTSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(rowTint.opacity(isHovered ? 0.12 : 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(rowTint.opacity(isHovered ? 0.25 : 0.12), lineWidth: 1)
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous))
        .onHover { isHovered = $0 }
    }
    
    private func actionIcon(
        systemName: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 26, height: 26)
                .background(background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Tunnel Row

struct MenuBarQuickTunnelRow: View {
    let tunnel: QuickTunnel
    @EnvironmentObject var tunnelService: TunnelService
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: CTSpacing.md) {
            CTIconBadge(
                icon: "bolt.horizontal.circle.fill",
                color: tunnel.status == .running ? CTColors.success : CTColors.textTertiary,
                size: 30
            )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(tunnel.displayName)
                    .font(CTTypography.callout)
                    .foregroundStyle(CTColors.textPrimary)
                    .lineLimit(1)
                
                Text(tunnel.publicURL ?? tunnel.localURL)
                    .font(CTTypography.monoSmall)
                    .foregroundStyle(CTColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                tunnelService.stopQuickTunnel(tunnel)
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(CTColors.danger)
                    .frame(width: 26, height: 26)
                    .background(CTColors.danger.opacity(0.14))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CTSpacing.md)
        .padding(.vertical, CTSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(Color.primary.opacity(isHovered ? 0.16 : 0.1), lineWidth: 1)
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Small Components

struct MenuBarSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CTTypography.captionBold)
                .foregroundStyle(CTColors.textPrimary)
            
            Spacer()
            
            Text(subtitle)
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textTertiary)
        }
        .padding(.horizontal, CTSpacing.xs)
    }
}

struct MenuBarStatPill: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(CTTypography.captionBold)
                    .foregroundStyle(CTColors.textPrimary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(CTColors.textTertiary)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct MenuBarActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                
                Text(title)
                    .font(CTTypography.captionBold)
                    .lineLimit(1)
            }
            .foregroundStyle(isDisabled ? CTColors.textTertiary : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                    .fill((isDisabled ? CTColors.textTertiary : tint).opacity(isHovered ? 0.2 : 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                            .stroke((isDisabled ? CTColors.textTertiary : tint).opacity(isHovered ? 0.35 : 0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
    }
}
