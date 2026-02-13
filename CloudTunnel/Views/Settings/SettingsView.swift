// MARK: - Settings View
// Comprehensive settings with tabbed interface

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @EnvironmentObject var mampService: MAMPService
    @EnvironmentObject var backupService: BackupService
    @EnvironmentObject var historyService: HistoryService
    
    @State private var selectedTab = SettingsTab.general
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general, paths, appearance, notifications, backup, advanced, about
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .general:       NSLocalizedString("settings.general", comment: "")
            case .paths:         NSLocalizedString("settings.paths", comment: "")
            case .appearance:    NSLocalizedString("settings.appearance", comment: "")
            case .notifications: NSLocalizedString("settings.notifications", comment: "")
            case .backup:        NSLocalizedString("settings.backup", comment: "")
            case .advanced:      NSLocalizedString("settings.advanced", comment: "")
            case .about:         NSLocalizedString("settings.about", comment: "")
            }
        }
        
        var icon: String {
            switch self {
            case .general:       "gearshape"
            case .paths:         "folder"
            case .appearance:    "paintbrush"
            case .notifications: "bell"
            case .backup:        "externaldrive"
            case .advanced:      "wrench.and.screwdriver"
            case .about:         "info.circle"
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Tab Sidebar
            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                                .frame(width: 20)
                            
                            Text(tab.title)
                                .font(CTTypography.headline)
                            
                            Spacer()
                        }
                        .foregroundStyle(selectedTab == tab ? CTColors.brand : CTColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                                .fill(selectedTab == tab ? CTColors.sidebarSelected : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(CTSpacing.md)
            .frame(width: 180)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                    switch selectedTab {
                    case .general:       generalTab
                    case .paths:         pathsTab
                    case .appearance:    appearanceTab
                    case .notifications: notificationsTab
                    case .backup:        backupTab
                    case .advanced:      advancedTab
                    case .about:         aboutTab
                    }
                }
                .padding(CTSpacing.xxl)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - General Tab
    var generalTab: some View {
        VStack(alignment: .leading, spacing: CTSpacing.xl) {
            Text(NSLocalizedString("settings.general", comment: ""))
                .font(CTTypography.title)
            
            // Cloudflared Path
            settingsGroup(title: "cloudflared") {
                HStack {
                    TextField("Path to cloudflared", text: $tunnelService.cloudflaredPath)
                        .textFieldStyle(.roundedBorder)
                        .font(CTTypography.mono)
                    
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            tunnelService.cloudflaredPath = url.path
                        }
                    }
                    
                    Button("Detect") {
                        tunnelService.resolveCloudflaredPath()
                    }
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(tunnelService.cloudflaredInstalled ? CTColors.success : CTColors.danger)
                        .frame(width: 8, height: 8)
                    
                    Text(tunnelService.cloudflaredInstalled
                         ? "cloudflared \(tunnelService.cloudflaredVersion ?? "") detected"
                         : "cloudflared not found")
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textSecondary)
                }
            }
            
            // Auto-Start
            settingsGroup(title: NSLocalizedString("settings.autoStart", comment: "")) {
                Toggle(NSLocalizedString("settings.autoStartTunnels", comment: ""), isOn: $tunnelService.autoStartTunnels)
                Toggle(NSLocalizedString("settings.autoStartMAMP", comment: ""), isOn: $mampService.autoStartMAMP)
            }
            
            // Check Interval
            settingsGroup(title: NSLocalizedString("settings.checkInterval", comment: "")) {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $tunnelService.checkInterval, in: 5...300, step: 5)
                    Text("\(Int(tunnelService.checkInterval))s")
                        .font(CTTypography.mono)
                        .foregroundStyle(CTColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Paths Tab
    var pathsTab: some View {
        VStack(alignment: .leading, spacing: CTSpacing.xl) {
            Text(NSLocalizedString("settings.paths", comment: ""))
                .font(CTTypography.title)
            
            settingsGroup(title: "Cloudflare") {
                pathField("Config Directory", text: $tunnelService.configDirectory)
            }
            
            settingsGroup(title: "MAMP") {
                pathField("Base Path", text: $mampService.mampBasePath)
                pathField("Sites Directory", text: $mampService.mampSitesDir)
                pathField("Apache Config", text: $mampService.mampApacheConfig)
                pathField("VHost Config", text: $mampService.mampVHostConfig)
                pathField("httpd.conf", text: $mampService.mampHttpdConf)
            }
        }
    }
    
    // MARK: - Appearance Tab
    @AppStorage("accentColorIndex") private var accentColorIndex = 0
    
    var appearanceTab: some View {
        VStack(alignment: .leading, spacing: CTSpacing.xl) {
            Text(NSLocalizedString("settings.appearance", comment: ""))
                .font(CTTypography.title)
            
            settingsGroup(title: NSLocalizedString("settings.accentColor", comment: "")) {
                let colors: [(String, Color)] = [
                    ("Blue", Color(hex: "4285FC")),
                    ("Purple", Color(hex: "7B61FF")),
                    ("Pink", Color(hex: "FF6B9D")),
                    ("Red", Color(hex: "FF3B30")),
                    ("Orange", Color(hex: "FF9F0A")),
                    ("Green", Color(hex: "34C759")),
                    ("Teal", Color(hex: "5AC8FA")),
                    ("Indigo", Color(hex: "5856D6")),
                ]
                
                HStack(spacing: CTSpacing.sm) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, item in
                        Button {
                            accentColorIndex = index
                        } label: {
                            Circle()
                                .fill(item.1)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                        .opacity(accentColorIndex == index ? 1 : 0)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(item.1, lineWidth: 2)
                                        .scaleEffect(1.3)
                                        .opacity(accentColorIndex == index ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Notifications Tab
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notifyOnTunnelStart") private var notifyOnTunnelStart = true
    @AppStorage("notifyOnTunnelStop") private var notifyOnTunnelStop = true
    @AppStorage("notifyOnError") private var notifyOnError = true
    
    var notificationsTab: some View {
        VStack(alignment: .leading, spacing: CTSpacing.xl) {
            Text(NSLocalizedString("settings.notifications", comment: ""))
                .font(CTTypography.title)
            
            settingsGroup(title: NSLocalizedString("settings.notifSettings", comment: "")) {
                Toggle(NSLocalizedString("settings.enableNotif", comment: ""), isOn: $notificationsEnabled)
                
                if notificationsEnabled {
                    Divider()
                    Toggle(NSLocalizedString("settings.notifStart", comment: ""), isOn: $notifyOnTunnelStart)
                    Toggle(NSLocalizedString("settings.notifStop", comment: ""), isOn: $notifyOnTunnelStop)
                    Toggle(NSLocalizedString("settings.notifError", comment: ""), isOn: $notifyOnError)
                }
            }
        }
    }
    
    // MARK: - Backup Tab
    @State private var showImportDialog = false
    
    var backupTab: some View {
        VStack(alignment: .leading, spacing: CTSpacing.xl) {
            Text(NSLocalizedString("settings.backup", comment: ""))
                .font(CTTypography.title)
            
            settingsGroup(title: NSLocalizedString("settings.backupActions", comment: "")) {
                HStack(spacing: CTSpacing.sm) {
                    CTButton(NSLocalizedString("backup.create", comment: ""), icon: "plus", style: .primary) {
                        Task { _ = try? await backupService.createBackup() }
                    }
                    
                    CTButton(NSLocalizedString("backup.import", comment: ""), icon: "square.and.arrow.down", style: .secondary) {
                        showImportDialog = true
                    }
                }
                
                Toggle(NSLocalizedString("backup.auto", comment: ""), isOn: $backupService.autoBackup)
            }
            
            // Backup List
            if !backupService.backups.isEmpty {
                settingsGroup(title: NSLocalizedString("backup.list", comment: "")) {
                    ForEach(backupService.backups) { backup in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(backup.name)
                                    .font(CTTypography.headline)
                                
                                Text("\(backup.tunnelCount) tunnels • \(ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file))")
                                    .font(CTTypography.caption)
                                    .foregroundStyle(CTColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text(backup.createdAt, style: .relative)
                                .font(CTTypography.caption)
                                .foregroundStyle(CTColors.textTertiary)
                            
                            Button {
                                Task { try? await backupService.restoreBackup(backup) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                backupService.deleteBackup(backup)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(CTColors.danger)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        
                        if backup.id != backupService.backups.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showImportDialog, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                Task { try? await backupService.importBackup(from: url) }
            }
        }
    }
    
    // MARK: - Advanced Tab
    var advancedTab: some View {
        VStack(alignment: .leading, spacing: CTSpacing.xl) {
            Text(NSLocalizedString("settings.advanced", comment: ""))
                .font(CTTypography.title)
            
            settingsGroup(title: "Cloudflare") {
                // Login status
                HStack(spacing: CTSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(tunnelService.isLoggedIn ? CTColors.success.opacity(0.12) : CTColors.warning.opacity(0.12))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: tunnelService.isLoggedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                            .font(.system(size: 16))
                            .foregroundStyle(tunnelService.isLoggedIn ? CTColors.success : CTColors.warning)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tunnelService.isLoggedIn ? "Cloudflare'a giriş yapıldı" : "Cloudflare'a giriş yapılmadı")
                            .font(CTTypography.callout)
                            .foregroundStyle(CTColors.textPrimary)
                        
                        Text(tunnelService.isLoggedIn
                             ? "cert.pem mevcut — tüneller oluşturulabilir"
                             : "Tünel oluşturmak için giriş yapmanız gerekiyor")
                            .font(CTTypography.caption)
                            .foregroundStyle(CTColors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, CTSpacing.sm)
                
                // Login error message
                if let error = tunnelService.loginError {
                    HStack(spacing: CTSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(CTColors.danger)
                            .font(.system(size: 12))
                        Text(error)
                            .font(CTTypography.caption)
                            .foregroundStyle(CTColors.danger)
                    }
                    .padding(.bottom, CTSpacing.sm)
                }
                
                HStack(spacing: CTSpacing.sm) {
                    CTButton("Open Dashboard", icon: "arrow.up.right", style: .secondary) {
                        NSWorkspace.shared.open(URL(string: "https://dash.cloudflare.com")!)
                    }
                    
                    if tunnelService.isLoggingIn {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Giriş bekleniyor...")
                                .font(CTTypography.caption)
                                .foregroundStyle(CTColors.textSecondary)
                        }
                        .padding(.horizontal, CTSpacing.md)
                    } else if tunnelService.isLoggedIn {
                        CTButton("Çıkış Yap", icon: "rectangle.portrait.and.arrow.right", style: .danger) {
                            tunnelService.cloudflareLogout()
                        }
                    } else {
                        CTButton("Giriş Yap", icon: "person.crop.circle", style: .primary) {
                            Task { await tunnelService.cloudflareLogin() }
                        }
                    }
                }
            }
            
            if mampService.isMAMPInstalled {
                settingsGroup(title: "MAMP Tools") {
                    HStack(spacing: CTSpacing.sm) {
                        CTButton(NSLocalizedString("mamp.fixMySQL", comment: ""), icon: "wrench", style: .secondary) {
                            Task { await mampService.fixMySQLSocket() }
                        }
                        
                        CTButton(NSLocalizedString("mamp.fixPhpMyAdmin", comment: ""), icon: "wrench", style: .secondary) {
                            mampService.fixPhpMyAdmin()
                        }
                    }
                }
            }
            
            settingsGroup(title: NSLocalizedString("settings.dangerZone", comment: "")) {
                CTButton(NSLocalizedString("settings.clearLogs", comment: ""), icon: "trash", style: .danger) {
                    historyService.clearLogs()
                }
            }
        }
    }
    
    // MARK: - About Tab
    var aboutTab: some View {
        VStack(alignment: .leading, spacing: CTSpacing.xl) {
            HStack(spacing: CTSpacing.xl) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(CTColors.brandGradient)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("CloudTunnel")
                        .font(CTTypography.largeTitle)
                    
                    Text("Version 1.0.0")
                        .font(CTTypography.body)
                        .foregroundStyle(CTColors.textSecondary)
                    
                    Text("Cloudflare Tunnel Manager for macOS")
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textTertiary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: CTSpacing.sm) {
                CTInfoRow(label: "Platform", value: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                CTInfoRow(label: "Architecture", value: {
                    #if arch(arm64)
                    return "Apple Silicon"
                    #else
                    return "Intel x86_64"
                    #endif
                }())
                CTInfoRow(label: "Swift", value: "5.9")
                CTInfoRow(label: "Framework", value: "SwiftUI")
            }
        }
    }
    
    // MARK: - Helpers
    func settingsGroup(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            Text(title)
                .font(CTTypography.headline)
                .foregroundStyle(CTColors.textSecondary)
            
            VStack(alignment: .leading, spacing: CTSpacing.md) {
                content()
            }
            .ctCard()
        }
    }
    
    func pathField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CTTypography.captionBold)
                .foregroundStyle(CTColors.textSecondary)
            
            HStack {
                TextField(label, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(CTTypography.monoSmall)
                
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        text.wrappedValue = url.path
                    }
                }
            }
        }
    }
}
