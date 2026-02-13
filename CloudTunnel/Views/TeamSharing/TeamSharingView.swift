// MARK: - Team Sharing View
// Export/import tunnel configurations as .cloudtunnel files

import SwiftUI

struct TeamSharingView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @StateObject private var sharingService = TeamSharingService.shared
    
    @State private var selectedTab: SharingTab = .export
    @State private var exportDescription = ""
    @State private var includeVHosts = true
    @State private var selectedTunnelIDs: Set<UUID> = []
    @State private var selectAll = true
    
    // Import state
    @State private var selectedImportIDs: Set<String> = []
    @State private var createConfigs = true
    
    enum SharingTab: String, CaseIterable {
        case export = "Dışa Aktar"
        case `import` = "İçe Aktar"
        
        var icon: String {
            switch self {
            case .export: "square.and.arrow.up"
            case .import: "square.and.arrow.down"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                    // Tab Picker
                    tabPicker
                    
                    // Info
                    infoCard
                    
                    // Content
                    switch selectedTab {
                    case .export:
                        exportSection
                    case .import:
                        importSection
                    }
                }
                .padding(CTSpacing.xxl)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Takım Paylaşımı")
                    .font(CTTypography.title)
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("Tünel konfigürasyonlarını .cloudtunnel dosyası olarak paylaş")
                    .font(CTTypography.callout)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(CTSpacing.lg)
    }
    
    // MARK: - Tab Picker
    var tabPicker: some View {
        HStack(spacing: CTSpacing.sm) {
            ForEach(SharingTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13))
                        Text(tab.rawValue)
                            .font(CTTypography.headline)
                    }
                    .foregroundStyle(selectedTab == tab ? .white : CTColors.textSecondary)
                    .padding(.horizontal, CTSpacing.lg)
                    .padding(.vertical, CTSpacing.sm)
                    .background(selectedTab == tab ? CTColors.brand : Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
    
    // MARK: - Info Card
    var infoCard: some View {
        HStack(spacing: CTSpacing.md) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 20))
                .foregroundStyle(CTColors.brand)
            
            VStack(alignment: .leading, spacing: 4) {
                if selectedTab == .export {
                    Text("Tünel konfigürasyonlarınızı .cloudtunnel dosyası olarak dışa aktarın ve takım arkadaşlarınızla paylaşın.")
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textPrimary)
                    Text("Güvenlik: Credentials dosyaları dışa aktarılmaz. Her kullanıcı kendi Cloudflare hesabıyla giriş yapmalıdır.")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                } else {
                    Text("Takım arkadaşınızdan aldığınız .cloudtunnel dosyasını içe aktararak tünel konfigürasyonlarını hızlıca kurun.")
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textPrimary)
                    Text("İçe aktarılan config dosyaları ~/.cloudflared/ dizinine kaydedilir.")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                }
            }
            
            Spacer()
        }
        .padding(CTSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(CTColors.brand.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(CTColors.brand.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Export Section
    var exportSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.lg) {
            // Tunnel Selection
            VStack(alignment: .leading, spacing: CTSpacing.md) {
                HStack {
                    CTSectionHeader(title: "Tünelleri Seç (\(selectedTunnelIDs.count)/\(tunnelService.managedTunnels.count))")
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            if selectAll {
                                selectedTunnelIDs = Set(tunnelService.managedTunnels.map { $0.id })
                            } else {
                                selectedTunnelIDs.removeAll()
                            }
                            selectAll.toggle()
                        }
                    } label: {
                        Text(selectAll ? "Tümünü Seç" : "Hiçbirini Seçme")
                            .font(CTTypography.captionBold)
                            .foregroundStyle(CTColors.brand)
                    }
                    .buttonStyle(.plain)
                }
                
                if tunnelService.managedTunnels.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: CTSpacing.sm) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundStyle(CTColors.textTertiary)
                            Text("Dışa aktarılacak tünel bulunamadı")
                                .font(CTTypography.callout)
                                .foregroundStyle(CTColors.textTertiary)
                        }
                        .padding(.vertical, CTSpacing.xxl)
                        Spacer()
                    }
                } else {
                    VStack(spacing: CTSpacing.xs) {
                        ForEach(tunnelService.managedTunnels) { tunnel in
                            ExportTunnelRow(
                                tunnel: tunnel,
                                isSelected: selectedTunnelIDs.contains(tunnel.id),
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if selectedTunnelIDs.contains(tunnel.id) {
                                            selectedTunnelIDs.remove(tunnel.id)
                                        } else {
                                            selectedTunnelIDs.insert(tunnel.id)
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
            
            // Options
            VStack(alignment: .leading, spacing: CTSpacing.md) {
                CTSectionHeader(title: "Seçenekler")
                
                VStack(spacing: CTSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Açıklama")
                                .font(CTTypography.captionBold)
                                .foregroundStyle(CTColors.textSecondary)
                            TextField("Bu paket hakkında not ekleyin (opsiyonel)", text: $exportDescription)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    Toggle("VHost yapılandırmalarını dahil et", isOn: $includeVHosts)
                        .font(CTTypography.body)
                }
                .ctCard()
            }
            
            // Export Button
            HStack {
                if let error = sharingService.exportError {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CTColors.danger)
                        Text(error)
                            .font(CTTypography.caption)
                            .foregroundStyle(CTColors.danger)
                    }
                }
                
                if let url = sharingService.lastExportURL {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CTColors.success)
                        Text(url.lastPathComponent)
                            .font(CTTypography.monoSmall)
                            .foregroundStyle(CTColors.success)
                    }
                }
                
                Spacer()
                
                CTButton("Dışa Aktar", icon: "square.and.arrow.up", style: .primary) {
                    let selected = tunnelService.managedTunnels.filter { selectedTunnelIDs.contains($0.id) }
                    sharingService.exportWithSavePanel(selected, description: exportDescription, includeVHosts: includeVHosts)
                }
                .disabled(selectedTunnelIDs.isEmpty || sharingService.isExporting)
            }
        }
    }
    
    // MARK: - Import Section
    var importSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.lg) {
            // Import button
            if sharingService.importPreview == nil {
                HStack {
                    Spacer()
                    
                    VStack(spacing: CTSpacing.lg) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.system(size: 40))
                            .foregroundStyle(CTColors.brand.opacity(0.5))
                        
                        Text(".cloudtunnel dosyası seçin")
                            .font(CTTypography.headline)
                            .foregroundStyle(CTColors.textSecondary)
                        
                        CTButton("Dosya Seç", icon: "folder", style: .primary) {
                            sharingService.importWithOpenPanel()
                        }
                        
                        if let error = sharingService.importError {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(CTColors.danger)
                                Text(error)
                                    .font(CTTypography.caption)
                                    .foregroundStyle(CTColors.danger)
                            }
                        }
                    }
                    .padding(.vertical, CTSpacing.xxl)
                    
                    Spacer()
                }
                .ctCard()
            }
            
            // Preview
            if let package = sharingService.importPreview {
                importPreviewSection(package)
            }
            
            // Results
            if !sharingService.importResults.isEmpty {
                importResultsSection
            }
        }
    }
    
    // MARK: - Import Preview
    func importPreviewSection(_ package: TunnelPackage) -> some View {
        VStack(alignment: .leading, spacing: CTSpacing.lg) {
            // Package Info
            VStack(alignment: .leading, spacing: CTSpacing.md) {
                CTSectionHeader(title: "Paket Bilgileri")
                
                VStack(spacing: CTSpacing.sm) {
                    CTInfoRow(label: "Dışa Aktaran", value: package.exportedBy)
                    CTInfoRow(label: "Tarih", value: package.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    CTInfoRow(label: "Versiyon", value: package.version)
                    CTInfoRow(label: "Tünel Sayısı", value: "\(package.tunnels.count)")
                    if !package.vhostEntries.isEmpty {
                        CTInfoRow(label: "VHost Sayısı", value: "\(package.vhostEntries.count)")
                    }
                    if !package.description.isEmpty {
                        CTInfoRow(label: "Açıklama", value: package.description)
                    }
                }
                .ctCard()
            }
            
            // Tunnel Selection
            VStack(alignment: .leading, spacing: CTSpacing.md) {
                HStack {
                    CTSectionHeader(title: "İçe Aktarılacak Tüneller")
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            if selectedImportIDs.count == package.tunnels.count {
                                selectedImportIDs.removeAll()
                            } else {
                                selectedImportIDs = Set(package.tunnels.map { $0.id })
                            }
                        }
                    } label: {
                        Text(selectedImportIDs.count == package.tunnels.count ? "Hiçbirini Seçme" : "Tümünü Seç")
                            .font(CTTypography.captionBold)
                            .foregroundStyle(CTColors.brand)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(spacing: CTSpacing.xs) {
                    ForEach(package.tunnels) { tunnel in
                        ImportTunnelRow(
                            tunnel: tunnel,
                            isSelected: selectedImportIDs.contains(tunnel.id),
                            alreadyExists: tunnelService.managedTunnels.contains(where: {
                                $0.tunnelUUID == tunnel.tunnelUUID && !tunnel.tunnelUUID.isEmpty
                            }),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedImportIDs.contains(tunnel.id) {
                                        selectedImportIDs.remove(tunnel.id)
                                    } else {
                                        selectedImportIDs.insert(tunnel.id)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            
            // Options & Actions
            VStack(spacing: CTSpacing.md) {
                Toggle("Config dosyalarını oluştur (credentials olmadan)", isOn: $createConfigs)
                    .font(CTTypography.body)
                
                HStack {
                    Button("Farklı Dosya Seç") {
                        sharingService.importPreview = nil
                        sharingService.importResults = []
                        sharingService.importWithOpenPanel()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CTColors.brand)
                    .font(CTTypography.captionBold)
                    
                    Spacer()
                    
                    if sharingService.isImporting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("İçe aktarılıyor...")
                                .font(CTTypography.callout)
                                .foregroundStyle(CTColors.textSecondary)
                        }
                    } else {
                        CTButton("İçe Aktar", icon: "square.and.arrow.down", style: .primary) {
                            Task {
                                await sharingService.applyImport(
                                    selectedTunnelIDs: selectedImportIDs,
                                    createConfigs: createConfigs
                                )
                            }
                        }
                        .disabled(selectedImportIDs.isEmpty)
                    }
                }
            }
            .ctCard()
        }
    }
    
    // MARK: - Import Results
    var importResultsSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            let successCount = sharingService.importResults.filter { $0.success }.count
            CTSectionHeader(title: "Sonuçlar (\(successCount)/\(sharingService.importResults.count) başarılı)")
            
            VStack(spacing: CTSpacing.sm) {
                ForEach(sharingService.importResults) { result in
                    HStack(spacing: CTSpacing.md) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? CTColors.success : CTColors.danger)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(CTTypography.headline)
                                .foregroundStyle(CTColors.textPrimary)
                            Text(result.message)
                                .font(CTTypography.caption)
                                .foregroundStyle(result.success ? CTColors.success : CTColors.danger)
                        }
                        
                        Spacer()
                    }
                    .padding(CTSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                            .fill(result.success ? CTColors.success.opacity(0.04) : CTColors.danger.opacity(0.04))
                    )
                }
            }
        }
    }
}

// MARK: - Export Tunnel Row
struct ExportTunnelRow: View {
    let tunnel: ManagedTunnel
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: CTSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? CTColors.brand : CTColors.textTertiary)
                
                CTIconBadge(icon: tunnel.tunnelProtocol.icon, color: tunnel.status.color, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tunnel.displayName)
                        .font(CTTypography.headline)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    HStack(spacing: CTSpacing.sm) {
                        if !tunnel.hostname.isEmpty {
                            Text(tunnel.hostname)
                                .font(CTTypography.monoSmall)
                                .foregroundStyle(CTColors.textSecondary)
                        }
                        Text(":\(tunnel.port)")
                            .font(CTTypography.monoSmall)
                            .foregroundStyle(CTColors.textTertiary)
                    }
                }
                
                Spacer()
                
                CTTag(text: tunnel.source.rawValue.capitalized, color: CTColors.textSecondary)
            }
            .padding(CTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                    .fill(isSelected ? CTColors.brand.opacity(0.06) : (isHovered ? Color.primary.opacity(0.03) : Color(nsColor: .controlBackgroundColor)))
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                            .stroke(isSelected ? CTColors.brand.opacity(0.2) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Import Tunnel Row
struct ImportTunnelRow: View {
    let tunnel: TunnelPackage.SharedTunnelConfig
    let isSelected: Bool
    let alreadyExists: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { if !alreadyExists { onToggle() } }) {
            HStack(spacing: CTSpacing.md) {
                Image(systemName: alreadyExists ? "exclamationmark.circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 18))
                    .foregroundStyle(alreadyExists ? CTColors.warning : (isSelected ? CTColors.brand : CTColors.textTertiary))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tunnel.name)
                        .font(CTTypography.headline)
                        .foregroundStyle(alreadyExists ? CTColors.textTertiary : CTColors.textPrimary)
                    
                    HStack(spacing: CTSpacing.sm) {
                        if !tunnel.hostname.isEmpty {
                            Text(tunnel.hostname)
                                .font(CTTypography.monoSmall)
                                .foregroundStyle(CTColors.textSecondary)
                        }
                        Text(":\(tunnel.port)")
                            .font(CTTypography.monoSmall)
                            .foregroundStyle(CTColors.textTertiary)
                        
                        Text(tunnel.tunnelProtocol.uppercased())
                            .font(CTTypography.captionBold)
                            .foregroundStyle(CTColors.textTertiary)
                    }
                }
                
                Spacer()
                
                if alreadyExists {
                    CTTag(text: "Mevcut", color: CTColors.warning)
                } else {
                    CTTag(text: tunnel.source.capitalized, color: CTColors.textSecondary)
                }
            }
            .padding(CTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                    .fill(alreadyExists ? CTColors.warning.opacity(0.04) : (isSelected ? CTColors.brand.opacity(0.06) : (isHovered ? Color.primary.opacity(0.03) : Color(nsColor: .controlBackgroundColor))))
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                            .stroke(alreadyExists ? CTColors.warning.opacity(0.2) : (isSelected ? CTColors.brand.opacity(0.2) : Color.primary.opacity(0.06)), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(alreadyExists ? 0.7 : 1)
    }
}
