// MARK: - MAMP View
// MAMP site management & tunnel creation

import SwiftUI

struct MAMPView: View {
    @EnvironmentObject var mampService: MAMPService
    @EnvironmentObject var tunnelService: TunnelService
    
    @State private var selectedSite: MAMPSite? = nil
    @State private var showTools = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            
            if !mampService.isMAMPInstalled {
                CTEmptyState(
                    icon: "server.rack",
                    title: NSLocalizedString("mamp.notInstalled.title", comment: ""),
                    message: NSLocalizedString("mamp.notInstalled.message", comment: "")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                        // Status Card
                        mampStatusCard
                        
                        // Sites
                        if !mampService.sites.isEmpty {
                            sitesSection
                        }
                        
                        // Tools
                        toolsSection
                    }
                    .padding(CTSpacing.xxl)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $selectedSite) { site in
            CreateFromMAMPSheet(site: site)
                .environmentObject(tunnelService)
                .environmentObject(mampService)
                .frame(minWidth: 480, minHeight: 400)
        }
    }
    
    // MARK: - Header
    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MAMP")
                    .font(CTTypography.title)
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("\(mampService.sites.count) " + NSLocalizedString("mamp.sitesCount", comment: ""))
                    .font(CTTypography.callout)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: CTSpacing.sm) {
                CTButton(NSLocalizedString("mamp.scan", comment: ""), icon: "arrow.clockwise", style: .secondary) {
                    mampService.scanSites()
                }
                
                if mampService.isStarting || mampService.isStopping {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(mampService.isStarting ? "Başlatılıyor..." : "Durduruluyor...")
                            .font(CTTypography.caption)
                            .foregroundStyle(CTColors.textSecondary)
                    }
                } else if mampService.isMAMPRunning {
                    CTButton(NSLocalizedString("mamp.stop", comment: ""), icon: "stop.fill", style: .danger) {
                        Task { await mampService.stopMAMP() }
                    }
                } else {
                    CTButton(NSLocalizedString("mamp.start", comment: ""), icon: "play.fill", style: .success) {
                        Task { await mampService.startMAMP() }
                    }
                }
            }
        }
        .padding(CTSpacing.lg)
    }
    
    // MARK: - Status Card
    var mampStatusCard: some View {
        VStack(spacing: CTSpacing.md) {
            HStack(spacing: CTSpacing.xl) {
                // MAMP Status
                HStack(spacing: CTSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(statusCircleColor.opacity(0.12))
                            .frame(width: 48, height: 48)
                        
                        if mampService.isStarting || mampService.isStopping {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "server.rack")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(statusCircleColor)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MAMP Server")
                            .font(CTTypography.headline)
                            .foregroundStyle(CTColors.textPrimary)
                        
                        Text(mampStatusText)
                            .font(CTTypography.callout)
                            .foregroundStyle(statusTextColor)
                    }
                }
                
                Spacer()
                
                // Quick Stats
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(mampService.sites.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text(NSLocalizedString("mamp.sites", comment: ""))
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textSecondary)
                }
            }
            
            // Status message banner
            if let message = mampService.lastStatusMessage {
                HStack(spacing: CTSpacing.sm) {
                    Image(systemName: mampService.statusMessageType == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(mampService.statusMessageType == .success ? CTColors.success : CTColors.danger)
                    
                    Text(message)
                        .font(CTTypography.callout)
                        .foregroundStyle(mampService.statusMessageType == .success ? CTColors.success : CTColors.danger)
                    
                    Spacer()
                }
                .padding(CTSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .fill(mampService.statusMessageType == .success ? CTColors.success.opacity(0.08) : CTColors.danger.opacity(0.08))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut, value: mampService.lastStatusMessage)
            }
        }
        .ctCard()
    }
    
    private var statusCircleColor: Color {
        if mampService.isStarting || mampService.isStopping { return CTColors.warning }
        return mampService.isMAMPRunning ? CTColors.success : CTColors.danger
    }
    
    private var statusTextColor: Color {
        if mampService.isStarting || mampService.isStopping { return CTColors.warning }
        return mampService.isMAMPRunning ? CTColors.success : CTColors.textSecondary
    }
    
    private var mampStatusText: String {
        if mampService.isStarting { return "Başlatılıyor..." }
        if mampService.isStopping { return "Durduruluyor..." }
        return mampService.isMAMPRunning
            ? NSLocalizedString("mamp.running", comment: "")
            : NSLocalizedString("mamp.stopped", comment: "")
    }
    
    // MARK: - Sites Section
    var sitesSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(title: NSLocalizedString("mamp.yourSites", comment: ""))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: CTSpacing.md) {
                ForEach(mampService.sites) { site in
                    SiteCard(site: site) {
                        selectedSite = site
                    }
                }
            }
        }
    }
    
    // MARK: - Tools Section
    var toolsSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(title: NSLocalizedString("mamp.tools", comment: ""))
            
            HStack(spacing: CTSpacing.md) {
                ToolCard(
                    title: NSLocalizedString("mamp.fixMySQL", comment: ""),
                    description: NSLocalizedString("mamp.fixMySQLDesc", comment: ""),
                    icon: "wrench.and.screwdriver",
                    color: CTColors.warning
                ) {
                    Task { await mampService.fixMySQLSocket() }
                }
                
                ToolCard(
                    title: NSLocalizedString("mamp.fixPhpMyAdmin", comment: ""),
                    description: NSLocalizedString("mamp.fixPhpMyAdminDesc", comment: ""),
                    icon: "wrench",
                    color: CTColors.info
                ) {
                    mampService.fixPhpMyAdmin()
                }
                
                ToolCard(
                    title: NSLocalizedString("mamp.refreshStatus", comment: ""),
                    description: NSLocalizedString("mamp.refreshStatusDesc", comment: ""),
                    icon: "arrow.clockwise",
                    color: CTColors.brand
                ) {
                    mampService.checkMAMPStatus()
                    mampService.scanSites()
                }
            }
        }
    }
}

// MARK: - Site Card
struct SiteCard: View {
    let site: MAMPSite
    let onCreateTunnel: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            HStack {
                CTIconBadge(icon: "globe", color: CTColors.brand, size: 36)
                Spacer()
                if !site.vhosts.isEmpty {
                    Text("\(site.vhosts.count) VHost")
                        .font(CTTypography.monoSmall)
                        .foregroundStyle(CTColors.brand)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CTColors.brand.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(site.name)
                    .font(CTTypography.headline)
                    .foregroundStyle(CTColors.textPrimary)
                    .lineLimit(1)
                
                Text(site.path)
                    .font(CTTypography.caption)
                    .foregroundStyle(CTColors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // VHost info
            if !site.vhosts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(site.vhosts) { vhost in
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 9))
                                .foregroundStyle(CTColors.success)
                            
                            Text(vhost.serverName.isEmpty ? "—" : vhost.serverName)
                                .font(CTTypography.monoSmall)
                                .foregroundStyle(CTColors.textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(":\(vhost.port)")
                                .font(CTTypography.monoSmall)
                                .foregroundStyle(CTColors.info)
                        }
                    }
                }
                .padding(CTSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("Port: \(site.port) (varsayılan)")
                        .font(CTTypography.monoSmall)
                }
                .foregroundStyle(CTColors.textTertiary)
            }
            
            Spacer(minLength: 4)
            
            // Always-visible Create Tunnel button
            Button(action: onCreateTunnel) {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Tünel Oluştur")
                        .font(CTTypography.captionBold)
                }
                .foregroundStyle(CTColors.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(CTColors.brand.opacity(isHovered ? 0.15 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(CTSpacing.lg)
        .frame(minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(Color.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Tool Card
struct ToolCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CTSpacing.md) {
                CTIconBadge(icon: icon, color: color, size: 36)
                
                Text(title)
                    .font(CTTypography.headline)
                    .foregroundStyle(CTColors.textPrimary)
                
                Text(description)
                    .font(CTTypography.caption)
                    .foregroundStyle(CTColors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CTSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                    .fill(isHovered ? color.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                            .stroke(color.opacity(isHovered ? 0.2 : 0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Create from MAMP Sheet
struct CreateFromMAMPSheet: View {
    let site: MAMPSite
    
    @EnvironmentObject var tunnelService: TunnelService
    @EnvironmentObject var mampService: MAMPService
    @Environment(\.dismiss) var dismiss
    
    @State private var tunnelName = ""
    @State private var hostname = ""
    @State private var port = "8888"
    @State private var updateVHost = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Tunnel from MAMP Site")
                    .font(CTTypography.title2)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(CTSpacing.xl)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: CTSpacing.xl) {
                    HStack(spacing: CTSpacing.md) {
                        CTIconBadge(icon: "globe", color: CTColors.brand, size: 40)
                        VStack(alignment: .leading) {
                            Text(site.name).font(CTTypography.headline)
                            Text(site.path).font(CTTypography.caption).foregroundStyle(CTColors.textSecondary)
                        }
                    }
                    
                    field("Tunnel Name", text: $tunnelName, placeholder: site.name)
                    field("Hostname", text: $hostname, placeholder: "\(site.name).example.com")
                    field("Port", text: $port, placeholder: "8888")
                    
                    Toggle("Update MAMP VHost Configuration", isOn: $updateVHost)
                        .font(CTTypography.body)
                    
                    if let error = errorMessage {
                        Text(error).font(CTTypography.callout).foregroundStyle(CTColors.danger)
                    }
                }
                .padding(CTSpacing.xl)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button {
                    createTunnel()
                } label: {
                    HStack {
                        if isCreating { ProgressView().controlSize(.small) }
                        Text("Create Tunnel")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tunnelName.isEmpty || isCreating)
            }
            .padding(CTSpacing.lg)
        }
        .onAppear {
            tunnelName = site.name
            port = "\(site.port)"
        }
    }
    
    func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(CTTypography.headline)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }
    
    func createTunnel() {
        isCreating = true
        errorMessage = nil
        let portNum = Int(port) ?? 8888
        let finalName = tunnelName.isEmpty ? site.name : tunnelName
        
        Task {
            do {
                let tunnel = try await tunnelService.createTunnel(
                    name: finalName, hostname: hostname,
                    port: portNum, protocol: .http, source: .mamp
                )
                
                if updateVHost && !hostname.isEmpty {
                    try? mampService.addVHost(hostname: hostname, sitePath: site.path, port: portNum)
                }
                
                // Auto-start the tunnel
                await tunnelService.startTunnel(tunnel)
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}
