// MARK: - Domain Migration View
// UI for scanning and migrating domains across all configs

import SwiftUI

struct DomainMigrationView: View {
    @StateObject private var migrationService = DomainMigrationService()
    @EnvironmentObject var tunnelService: TunnelService
    
    @State private var selectedDomain: String? = nil
    @State private var oldDomainText = ""
    @State private var newDomain = ""
    @State private var updateDNS = true
    @State private var showConfirmation = false
    @State private var showResults = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                    // Info card
                    infoCard
                    
                    // Migration panel (always visible)
                    migrationPanel
                    
                    // Scan results
                    if !migrationService.allDomains.isEmpty {
                        domainListSection
                    }
                    
                    // Results
                    if !migrationService.migrationResults.isEmpty {
                        resultsSection
                    }
                }
                .padding(CTSpacing.xxl)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            migrationService.scanAllDomains()
        }
        .alert("Domain Değiştir", isPresented: $showConfirmation) {
            Button("İptal", role: .cancel) { }
            Button("Değiştir", role: .destructive) {
                performMigration()
            }
        } message: {
            let old = effectiveOldDomain
            let count = migrationService.occurrences.filter { $0.domain == old }.count
            if count > 0 {
                Text("'\(old)' → '\(newDomain)'\n\n\(count) konumda güncelleme yapılacak. Bu işlem geri alınamaz.\n\nConfig dosyaları, VHost yapılandırması\(updateDNS ? ", Cloudflare DNS" : "") güncellenecek.")
            } else {
                Text("'\(old)' → '\(newDomain)'\n\nTüm config dosyalarında, VHost yapılandırmasında\(updateDNS ? ", Cloudflare DNS'de" : "") arama yapılıp güncellenecek. Bu işlem geri alınamaz.")
            }
        }
    }
    
    // MARK: - Header
    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Domain Yönetimi")
                    .font(CTTypography.title)
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("Tüm config dosyalarındaki domainleri tek seferde değiştir")
                    .font(CTTypography.callout)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
            
            CTButton("Tara", icon: "magnifyingglass", style: .primary) {
                migrationService.scanAllDomains()
            }
            .disabled(migrationService.isScanning)
        }
        .padding(CTSpacing.lg)
    }
    
    // MARK: - Info Card
    var infoCard: some View {
        HStack(spacing: CTSpacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(CTColors.info)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Domain değişikliği şu konumlarda aranır ve güncellenir:")
                    .font(CTTypography.headline)
                    .foregroundStyle(CTColors.textPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    bulletPoint("Cloudflared tunnel config dosyaları (.yml)")
                    bulletPoint("Apache VHost yapılandırması (httpd-vhosts.conf)")
                    bulletPoint("/etc/hosts dosyası")
                    bulletPoint("Uygulama içi tünel kayıtları")
                    bulletPoint("Cloudflare DNS yönlendirmeleri")
                }
            }
            
            Spacer()
        }
        .padding(CTSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(CTColors.info.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(CTColors.info.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    func bulletPoint(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(CTColors.textTertiary)
                .frame(width: 4, height: 4)
            Text(text)
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textSecondary)
        }
    }
    
    // MARK: - Domain List
    var domainListSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(title: "Bulunan Domainler (\(migrationService.allDomains.count))")
            
            VStack(spacing: CTSpacing.sm) {
                ForEach(migrationService.allDomains, id: \.self) { domain in
                    DomainRow(
                        domain: domain,
                        occurrences: migrationService.occurrences.filter { $0.domain == domain },
                        isSelected: selectedDomain == domain,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedDomain == domain {
                                    selectedDomain = nil
                                    oldDomainText = ""
                                    newDomain = ""
                                } else {
                                    selectedDomain = domain
                                    oldDomainText = domain
                                    newDomain = ""
                                    migrationService.migrationResults = []
                                }
                            }
                        }
                    )
                }
            }
        }
    }
    
    /// The effective old domain: either selected from list or manually typed
    var effectiveOldDomain: String {
        selectedDomain ?? (oldDomainText.isEmpty ? "" : oldDomainText)
    }
    
    // MARK: - Migration Panel
    var migrationPanel: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(title: "Domain Değiştir")
            
            VStack(spacing: CTSpacing.lg) {
                // Old & New domain fields
                HStack(spacing: CTSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mevcut Domain")
                            .font(CTTypography.captionBold)
                            .foregroundStyle(CTColors.textSecondary)
                        
                        if selectedDomain != nil {
                            // Selected from list - show as read-only with clear button
                            HStack {
                                Text(selectedDomain ?? "")
                                    .font(CTTypography.mono)
                                    .foregroundStyle(CTColors.danger)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation {
                                        selectedDomain = nil
                                        oldDomainText = ""
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(CTColors.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, CTSpacing.md)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                                    .fill(CTColors.danger.opacity(0.06))
                            )
                        } else {
                            // Manual entry
                            TextField("mevcut-domain.com", text: $oldDomainText)
                                .textFieldStyle(.roundedBorder)
                                .font(CTTypography.mono)
                        }
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CTColors.brand)
                        .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yeni Domain")
                            .font(CTTypography.captionBold)
                            .foregroundStyle(CTColors.textSecondary)
                        
                        TextField("yeni-domain.com", text: $newDomain)
                            .textFieldStyle(.roundedBorder)
                            .font(CTTypography.mono)
                    }
                }
                
                // Hint when no domain is selected and list is not empty
                if selectedDomain == nil && !migrationService.allDomains.isEmpty && oldDomainText.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CTColors.warning)
                        Text("Aşağıdaki listeden bir domain seçerek otomatik doldurabilir veya elle yazabilirsiniz.")
                            .font(CTTypography.caption)
                            .foregroundStyle(CTColors.textTertiary)
                    }
                }
                
                // Options
                HStack(spacing: CTSpacing.xl) {
                    Toggle("Cloudflare DNS yönlendirmesini güncelle", isOn: $updateDNS)
                        .font(CTTypography.body)
                    
                    if !tunnelService.isLoggedIn && updateDNS {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text("Cloudflare girişi gerekli")
                                .font(CTTypography.caption)
                        }
                        .foregroundStyle(CTColors.warning)
                    }
                    
                    Spacer()
                }
                
                // Locations to update
                if !effectiveOldDomain.isEmpty {
                    let locations = migrationService.occurrences.filter { $0.domain == effectiveOldDomain }
                    
                    VStack(alignment: .leading, spacing: CTSpacing.sm) {
                        Text("Güncellenecek konumlar (\(locations.count))")
                            .font(CTTypography.captionBold)
                            .foregroundStyle(CTColors.textSecondary)
                        
                        ForEach(locations) { occ in
                            HStack(spacing: CTSpacing.sm) {
                                Image(systemName: occ.location.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(CTColors.brand)
                                    .frame(width: 20)
                                
                                Text(occ.location.rawValue)
                                    .font(CTTypography.captionBold)
                                    .foregroundStyle(CTColors.textPrimary)
                                    .frame(width: 140, alignment: .leading)
                                
                                Text(occ.linePreview)
                                    .font(CTTypography.monoSmall)
                                    .foregroundStyle(CTColors.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(CTSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                }
                
                // Action button
                HStack {
                    Spacer()
                    
                    if migrationService.isMigrating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Güncelleniyor...")
                                .font(CTTypography.callout)
                                .foregroundStyle(CTColors.textSecondary)
                        }
                    } else {
                        CTButton("Tüm Konumlarda Değiştir", icon: "arrow.triangle.2.circlepath", style: .primary) {
                            showConfirmation = true
                        }
                        .disabled(effectiveOldDomain.isEmpty || newDomain.isEmpty || newDomain == effectiveOldDomain)
                    }
                }
            }
            .ctCard()
        }
    }
    
    // MARK: - Results
    var resultsSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            let successCount = migrationService.migrationResults.filter { $0.success }.count
            let totalCount = migrationService.migrationResults.count
            
            CTSectionHeader(title: "Sonuçlar (\(successCount)/\(totalCount) başarılı)")
            
            VStack(spacing: CTSpacing.sm) {
                ForEach(migrationService.migrationResults) { result in
                    HStack(spacing: CTSpacing.md) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? CTColors.success : CTColors.danger)
                        
                        Image(systemName: result.location.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(CTColors.textSecondary)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.location.rawValue)
                                .font(CTTypography.captionBold)
                                .foregroundStyle(CTColors.textPrimary)
                            
                            Text(result.message)
                                .font(CTTypography.caption)
                                .foregroundStyle(result.success ? CTColors.success : CTColors.danger)
                        }
                        
                        Spacer()
                        
                        if result.filePath != "memory" && result.filePath != "cloudflare" {
                            Text(URL(fileURLWithPath: result.filePath).lastPathComponent)
                                .font(CTTypography.monoSmall)
                                .foregroundStyle(CTColors.textTertiary)
                        }
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
    
    // MARK: - Action
    func performMigration() {
        let old = effectiveOldDomain
        guard !old.isEmpty, !newDomain.isEmpty else { return }
        Task {
            _ = await migrationService.migrateDomain(from: old, to: newDomain, updateDNS: updateDNS)
            selectedDomain = nil
            oldDomainText = ""
        }
    }
}

// MARK: - Domain Row
struct DomainRow: View {
    let domain: String
    let occurrences: [DomainMigrationService.DomainOccurrence]
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: CTSpacing.sm) {
                HStack(spacing: CTSpacing.md) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? CTColors.brand : CTColors.textSecondary)
                        .frame(width: 24)
                    
                    Text(domain)
                        .font(CTTypography.mono)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Spacer()
                    
                    // Location badges
                    HStack(spacing: 4) {
                        let locationTypes = Set(occurrences.map { $0.location })
                        ForEach(Array(locationTypes), id: \.self) { locType in
                            HStack(spacing: 3) {
                                Image(systemName: locType.icon)
                                    .font(.system(size: 9))
                                Text(shortLabel(locType))
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(CTColors.brand)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(CTColors.brand.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text("\(occurrences.count) konum")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                    
                    Image(systemName: isSelected ? "chevron.up" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CTColors.textTertiary)
                }
                
                // Expanded: show occurrences
                if isSelected {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(occurrences) { occ in
                            HStack(spacing: 8) {
                                Image(systemName: occ.location.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(CTColors.textSecondary)
                                    .frame(width: 16)
                                
                                Text(occ.linePreview)
                                    .font(CTTypography.monoSmall)
                                    .foregroundStyle(CTColors.textTertiary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(occ.location.rawValue)
                                    .font(.system(size: 9))
                                    .foregroundStyle(CTColors.textTertiary)
                            }
                        }
                    }
                    .padding(.leading, 40)
                    .padding(.top, 4)
                }
            }
            .padding(CTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                    .fill(isSelected ? CTColors.brand.opacity(0.06) : (isHovered ? Color.primary.opacity(0.03) : Color(nsColor: .controlBackgroundColor)))
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                            .stroke(isSelected ? CTColors.brand.opacity(0.2) : Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    func shortLabel(_ type: DomainMigrationService.DomainOccurrence.LocationType) -> String {
        switch type {
        case .tunnelConfig: return "Config"
        case .vhostConfig: return "VHost"
        case .hostsFile: return "Hosts"
        case .tunnelModel: return "Tünel"
        case .dnsRoute: return "DNS"
        }
    }
}
