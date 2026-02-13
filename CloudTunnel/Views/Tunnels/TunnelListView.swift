// MARK: - Tunnel List View
// Displays all managed tunnels with search, filter, and actions

import SwiftUI

struct TunnelListView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @State private var searchText = ""
    @State private var filterStatus: TunnelStatus? = nil
    @State private var showCreateSheet = false
    @State private var selectedTunnel: ManagedTunnel? = nil
    @State private var showDeleteAlert = false
    @State private var tunnelToDelete: ManagedTunnel? = nil
    @State private var filterFavoritesOnly = false
    
    var filteredTunnels: [ManagedTunnel] {
        tunnelService.sortedTunnels.filter { tunnel in
            if let filter = filterStatus, tunnel.status != filter { return false }
            if filterFavoritesOnly && !tunnel.isFavorite { return false }
            if !searchText.isEmpty {
                return tunnel.displayName.localizedCaseInsensitiveContains(searchText) ||
                       tunnel.name.localizedCaseInsensitiveContains(searchText) ||
                       tunnel.hostname.localizedCaseInsensitiveContains(searchText) ||
                       tunnel.tunnelUUID.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            Divider()
            
            if tunnelService.managedTunnels.isEmpty {
                CTEmptyState(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: NSLocalizedString("tunnels.empty.title", comment: ""),
                    message: NSLocalizedString("tunnels.empty.message", comment: ""),
                    action: { showCreateSheet = true },
                    actionTitle: NSLocalizedString("tunnels.create", comment: "")
                )
            } else {
                // Tunnel List
                ScrollView {
                    LazyVStack(spacing: CTSpacing.sm) {
                        ForEach(filteredTunnels) { tunnel in
                            TunnelRow(
                                tunnel: tunnel,
                                isSelected: selectedTunnel?.id == tunnel.id,
                                onSelect: { selectedTunnel = tunnel },
                                onStart: { Task { await tunnelService.startTunnel(tunnel) } },
                                onStop: { Task { await tunnelService.stopTunnel(tunnel) } },
                                onDelete: {
                                    tunnelToDelete = tunnel
                                    showDeleteAlert = true
                                },
                                onToggleFavorite: { tunnelService.toggleFavorite(tunnel) }
                            )
                        }
                    }
                    .padding(CTSpacing.lg)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showCreateSheet) {
            CreateTunnelView()
                .frame(minWidth: 520, minHeight: 480)
        }
        .alert(NSLocalizedString("tunnels.delete.title", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) {
                if let tunnel = tunnelToDelete {
                    Task { await tunnelService.deleteTunnel(tunnel) }
                }
            }
        } message: {
            Text(NSLocalizedString("tunnels.delete.message", comment: ""))
        }
    }
    
    // MARK: - Header
    var headerBar: some View {
        VStack(spacing: CTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("tunnels.title", comment: ""))
                        .font(CTTypography.title)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text("\(tunnelService.managedTunnels.count) " + NSLocalizedString("tunnels.count", comment: ""))
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: CTSpacing.sm) {
                    CTButton(NSLocalizedString("action.startAll", comment: ""), icon: "play.fill", style: .success) {
                        Task { await tunnelService.startAllTunnels() }
                    }
                    
                    CTButton(NSLocalizedString("action.stopAll", comment: ""), icon: "stop.fill", style: .danger) {
                        Task { await tunnelService.stopAllTunnels() }
                    }
                    
                    CTButton(NSLocalizedString("tunnels.create", comment: ""), icon: "plus", style: .primary) {
                        showCreateSheet = true
                    }
                }
            }
            
            HStack(spacing: CTSpacing.sm) {
                CTSearchBar(text: $searchText, placeholder: NSLocalizedString("tunnels.search", comment: ""))
                
                // Filter chips
                filterChip(nil, title: NSLocalizedString("filter.all", comment: ""))
                filterChip(.running, title: NSLocalizedString("status.running", comment: ""))
                filterChip(.stopped, title: NSLocalizedString("status.stopped", comment: ""))
                filterChip(.error, title: NSLocalizedString("status.error", comment: ""))
                
                Divider()
                    .frame(height: 20)
                
                Button {
                    withAnimation { filterFavoritesOnly.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filterFavoritesOnly ? "star.fill" : "star")
                            .font(.system(size: 11))
                        Text("Favoriler")
                            .font(CTTypography.captionBold)
                    }
                    .foregroundStyle(filterFavoritesOnly ? .white : CTColors.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(filterFavoritesOnly ? CTColors.warning : CTColors.warning.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(CTSpacing.lg)
    }
    
    func filterChip(_ status: TunnelStatus?, title: String) -> some View {
        Button {
            withAnimation { filterStatus = status }
        } label: {
            Text(title)
                .font(CTTypography.captionBold)
                .foregroundStyle(filterStatus == status ? .white : CTColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(filterStatus == status ? CTColors.brand : Color.primary.opacity(0.06))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tunnel Row
struct TunnelRow: View {
    let tunnel: ManagedTunnel
    let isSelected: Bool
    let onSelect: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    
    @EnvironmentObject var tunnelService: TunnelService
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var dnsHostname = ""
    @State private var isDNSRouting = false
    @State private var dnsMessage: String?
    @State private var dnsMessageIsError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: CTSpacing.lg) {
                // Status & Icon
                CTIconBadge(
                    icon: tunnel.tunnelProtocol.icon,
                    color: tunnel.status.color,
                    size: 40
                )
                
                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: CTSpacing.sm) {
                        Text(tunnel.displayName)
                            .font(CTTypography.headline)
                            .foregroundStyle(CTColors.textPrimary)
                        
                        CTTag(text: tunnel.source.rawValue.capitalized, color: CTColors.textSecondary)
                    }
                    
                    HStack(spacing: CTSpacing.sm) {
                        if !tunnel.hostname.isEmpty {
                            Text(tunnel.hostname)
                                .font(CTTypography.monoSmall)
                                .foregroundStyle(CTColors.textSecondary)
                        }
                        
                        Text(":\(tunnel.port)")
                            .font(CTTypography.monoSmall)
                            .foregroundStyle(CTColors.textTertiary)
                        
                        Text("•")
                            .foregroundStyle(CTColors.textTertiary)
                        
                        Text(tunnel.tunnelProtocol.displayName)
                            .font(CTTypography.captionBold)
                            .foregroundStyle(CTColors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Status Badge
                CTStatusBadge(status: tunnel.status)
                
                // Favorite button
                Button(action: onToggleFavorite) {
                    Image(systemName: tunnel.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tunnel.isFavorite ? CTColors.warning : CTColors.textTertiary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                
                // Actions
                HStack(spacing: CTSpacing.xs) {
                    if tunnel.status == .running {
                        actionButton("stop.fill", color: CTColors.danger, action: onStop)
                    } else if tunnel.status == .stopped || tunnel.status == .error {
                        actionButton("play.fill", color: CTColors.success, action: onStart)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 30, height: 30)
                    }
                    
                    actionButton("chevron.down", color: CTColors.textTertiary) {
                        withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                    }
                    
                    actionButton("trash", color: CTColors.danger.opacity(0.7), action: onDelete)
                }
            }
            .padding(CTSpacing.lg)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            
            // Expanded Detail
            if isExpanded {
                Divider()
                    .padding(.horizontal, CTSpacing.lg)
                
                VStack(spacing: CTSpacing.sm) {
                    CTInfoRow(label: "Name", value: tunnel.displayName)
                    CTInfoRow(label: "Config Path", value: tunnel.configPath, isMono: true, copyable: true)
                    CTInfoRow(label: "Tunnel UUID", value: tunnel.tunnelUUID.isEmpty ? "—" : tunnel.tunnelUUID, isMono: true, copyable: true)
                    if !tunnel.hostname.isEmpty {
                        CTInfoRow(label: "Hostname", value: tunnel.hostname, isMono: true, copyable: true)
                    }
                    CTInfoRow(label: "Port", value: "\(tunnel.port)", isMono: true)
                    CTInfoRow(label: "Protocol", value: tunnel.tunnelProtocol.displayName)
                    CTInfoRow(label: "PID", value: tunnel.pid.map { String($0) } ?? "—", isMono: true)
                    CTInfoRow(label: "Created", value: tunnel.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let lastStarted = tunnel.lastStarted {
                        CTInfoRow(label: "Last Started", value: lastStarted.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    // DNS Routing Section
                    if !tunnel.tunnelUUID.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: CTSpacing.sm) {
                            Text("DNS Yönlendirme")
                                .font(CTTypography.captionBold)
                                .foregroundStyle(CTColors.textPrimary)
                            
                            HStack(spacing: CTSpacing.sm) {
                                TextField("subdomain.example.com", text: $dnsHostname)
                                    .textFieldStyle(.roundedBorder)
                                    .font(CTTypography.monoSmall)
                                    .onAppear { dnsHostname = tunnel.hostname }
                                
                                Button {
                                    routeDNS()
                                } label: {
                                    HStack(spacing: 4) {
                                        if isDNSRouting {
                                            ProgressView().controlSize(.mini)
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 10, weight: .semibold))
                                        }
                                        Text("Route DNS")
                                            .font(CTTypography.captionBold)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(CTColors.brand)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(dnsHostname.isEmpty || isDNSRouting)
                            }
                            
                            if let msg = dnsMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: dnsMessageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                    Text(msg)
                                        .font(CTTypography.caption)
                                }
                                .foregroundStyle(dnsMessageIsError ? CTColors.danger : CTColors.success)
                            }
                        }
                    }
                }
                .padding(CTSpacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                .fill(isHovered || isSelected
                      ? Color.primary.opacity(0.03)
                      : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                        .stroke(isSelected ? CTColors.brand.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
        .onHover { isHovered = $0 }
    }
    
    func actionButton(_ icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    func routeDNS() {
        isDNSRouting = true
        dnsMessage = nil
        
        Task {
            do {
                try await tunnelService.updateTunnelDNS(tunnel, hostname: dnsHostname)
                dnsMessage = "\(dnsHostname) → tünel yönlendirildi"
                dnsMessageIsError = false
            } catch {
                dnsMessage = error.localizedDescription
                dnsMessageIsError = true
            }
            isDNSRouting = false
            
            // Auto-dismiss after 5s
            try? await Task.sleep(for: .seconds(5))
            dnsMessage = nil
        }
    }
}
