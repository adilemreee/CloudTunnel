// MARK: - Quick Tunnel View
// Start temporary tunnels with presets for popular frameworks

import SwiftUI

struct QuickTunnelView: View {
    @EnvironmentObject var tunnelService: TunnelService
    
    @State private var selectedPreset: QuickTunnelPreset? = nil
    @State private var customURL = ""
    @State private var customPort = ""
    @State private var isStarting = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("quick.title", comment: ""))
                        .font(CTTypography.largeTitle)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text(NSLocalizedString("quick.subtitle", comment: ""))
                        .font(CTTypography.body)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                // Framework Presets
                VStack(alignment: .leading, spacing: CTSpacing.md) {
                    CTSectionHeader(title: NSLocalizedString("quick.presets", comment: ""))
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: CTSpacing.md) {
                        ForEach(QuickTunnelPreset.presets) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: selectedPreset?.id == preset.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPreset = preset
                                    customPort = "\(preset.defaultPort)"
                                    customURL = "http://localhost:\(preset.defaultPort)"
                                }
                            }
                        }
                    }
                }
                
                // Custom URL Input
                VStack(alignment: .leading, spacing: CTSpacing.md) {
                    CTSectionHeader(title: NSLocalizedString("quick.customURL", comment: ""))
                    
                    HStack(spacing: CTSpacing.sm) {
                        HStack(spacing: CTSpacing.sm) {
                            Image(systemName: "link")
                                .font(.system(size: 13))
                                .foregroundStyle(CTColors.textTertiary)
                            
                            TextField("http://localhost:3000", text: $customURL)
                                .textFieldStyle(.plain)
                                .font(CTTypography.mono)
                        }
                        .padding(.horizontal, CTSpacing.md)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                        
                        Button {
                            startQuickTunnel()
                        } label: {
                            HStack(spacing: 6) {
                                if isStarting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "bolt.horizontal.fill")
                                        .font(.system(size: 12))
                                }
                                Text(NSLocalizedString("quick.start", comment: ""))
                                    .font(CTTypography.headline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(CTColors.brand)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(customURL.isEmpty || isStarting)
                    }
                }
                .ctCard()
                
                // Active Quick Tunnels
                if !tunnelService.quickTunnels.isEmpty {
                    VStack(alignment: .leading, spacing: CTSpacing.md) {
                        CTSectionHeader(
                            title: NSLocalizedString("quick.active", comment: ""),
                            subtitle: "\(tunnelService.quickTunnels.count) " + NSLocalizedString("quick.activeCount", comment: "")
                        )
                        
                        ForEach(tunnelService.quickTunnels) { tunnel in
                            QuickTunnelCard(tunnel: tunnel)
                        }
                    }
                    .ctCard()
                }
            }
            .padding(CTSpacing.xxl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    func startQuickTunnel() {
        guard !customURL.isEmpty else { return }
        isStarting = true
        
        Task {
            _ = await tunnelService.startQuickTunnel(localURL: customURL, preset: selectedPreset)
            isStarting = false
        }
    }
}

// MARK: - Preset Card
struct PresetCard: View {
    let preset: QuickTunnelPreset
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: CTSpacing.sm) {
                Image(systemName: preset.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? preset.color : CTColors.textSecondary)
                
                Text(preset.name)
                    .font(CTTypography.headline)
                    .foregroundStyle(isSelected ? CTColors.textPrimary : CTColors.textSecondary)
                
                Text(":\(preset.defaultPort)")
                    .font(CTTypography.monoSmall)
                    .foregroundStyle(CTColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CTSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                    .fill(isSelected ? preset.color.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.primary.opacity(0.02)))
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                            .stroke(isSelected ? preset.color.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Quick Tunnel Card
struct QuickTunnelCard: View {
    let tunnel: QuickTunnel
    @EnvironmentObject var tunnelService: TunnelService
    @State private var isCopied = false
    
    var body: some View {
        HStack(spacing: CTSpacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(tunnel.status == .running ? CTColors.success.opacity(0.12) : CTColors.warning.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: tunnel.status == .running ? "bolt.horizontal.fill" : "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tunnel.status == .running ? CTColors.success : CTColors.warning)
                    .rotationEffect(tunnel.status == .starting ? .degrees(360) : .zero)
                    .animation(tunnel.status == .starting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: tunnel.status)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tunnel.displayName)
                    .font(CTTypography.headline)
                    .foregroundStyle(CTColors.textPrimary)
                
                Text(tunnel.localURL)
                    .font(CTTypography.monoSmall)
                    .foregroundStyle(CTColors.textSecondary)
                
                if let publicURL = tunnel.publicURL {
                    HStack(spacing: 4) {
                        Text(publicURL)
                            .font(CTTypography.monoSmall)
                            .foregroundStyle(CTColors.brand)
                            .textSelection(.enabled)
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(publicURL, forType: .string)
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(isCopied ? CTColors.success : CTColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()
            
            CTStatusBadge(status: tunnel.status)
            
            Button {
                tunnelService.stopQuickTunnel(tunnel)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CTColors.danger)
                    .frame(width: 28, height: 28)
                    .background(CTColors.danger.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(CTSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
