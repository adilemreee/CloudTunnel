// MARK: - Create Tunnel View
// Professional form for creating new managed tunnels

import SwiftUI

struct CreateTunnelView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @Environment(\.dismiss) var dismiss
    
    @State private var tunnelName = ""
    @State private var hostname = ""
    @State private var port = "80"
    @State private var selectedProtocol: TunnelProtocol = .http
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var currentStep = 0
    
    var isValid: Bool {
        !tunnelName.isEmpty && !port.isEmpty && Int(port) != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("create.title", comment: ""))
                        .font(CTTypography.title)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text(NSLocalizedString("create.subtitle", comment: ""))
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                Spacer()
                
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CTColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(CTSpacing.xxl)
            
            Divider()
            
            // Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                    // Protocol Selection
                    VStack(alignment: .leading, spacing: CTSpacing.sm) {
                        Text(NSLocalizedString("create.protocol", comment: ""))
                            .font(CTTypography.headline)
                            .foregroundStyle(CTColors.textPrimary)
                        
                        HStack(spacing: CTSpacing.sm) {
                            ForEach(TunnelProtocol.allCases, id: \.self) { proto in
                                protocolCard(proto)
                            }
                        }
                    }
                    
                    // Tunnel Name
                    formField(
                        label: NSLocalizedString("create.name", comment: ""),
                        placeholder: "my-tunnel",
                        text: $tunnelName,
                        icon: "tag"
                    )
                    
                    // Hostname
                    formField(
                        label: NSLocalizedString("create.hostname", comment: ""),
                        placeholder: "tunnel.example.com",
                        text: $hostname,
                        icon: "globe",
                        hint: NSLocalizedString("create.hostnameHint", comment: "")
                    )
                    
                    // Port
                    formField(
                        label: NSLocalizedString("create.port", comment: ""),
                        placeholder: "\(selectedProtocol.defaultPort)",
                        text: $port,
                        icon: "number"
                    )
                    
                    // Error
                    if let error = errorMessage {
                        HStack(spacing: CTSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(CTColors.danger)
                            Text(error)
                                .font(CTTypography.callout)
                                .foregroundStyle(CTColors.danger)
                        }
                        .padding(CTSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CTColors.danger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous))
                    }
                    
                    // Summary
                    if isValid {
                        summaryCard
                    }
                }
                .padding(CTSpacing.xxl)
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button {
                    createTunnel()
                } label: {
                    HStack(spacing: 6) {
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(NSLocalizedString("create.button", comment: ""))
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isCreating)
            }
            .padding(CTSpacing.lg)
        }
        .onChange(of: selectedProtocol) { _, newValue in
            port = "\(newValue.defaultPort)"
        }
    }
    
    // MARK: - Protocol Card
    func protocolCard(_ proto: TunnelProtocol) -> some View {
        Button {
            withAnimation { selectedProtocol = proto }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: proto.icon)
                    .font(.system(size: 18, weight: .medium))
                
                Text(proto.displayName)
                    .font(CTTypography.captionBold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                    .fill(selectedProtocol == proto ? CTColors.brand.opacity(0.12) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                            .stroke(selectedProtocol == proto ? CTColors.brand : .clear, lineWidth: 1.5)
                    )
            )
            .foregroundStyle(selectedProtocol == proto ? CTColors.brand : CTColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Form Field
    func formField(label: String, placeholder: String, text: Binding<String>, icon: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: CTSpacing.xs) {
            Text(label)
                .font(CTTypography.headline)
                .foregroundStyle(CTColors.textPrimary)
            
            HStack(spacing: CTSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(CTColors.textTertiary)
                    .frame(width: 20)
                
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(CTTypography.body)
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
            
            if let hint {
                Text(hint)
                    .font(CTTypography.caption)
                    .foregroundStyle(CTColors.textTertiary)
            }
        }
    }
    
    // MARK: - Summary
    var summaryCard: some View {
        VStack(alignment: .leading, spacing: CTSpacing.sm) {
            Text(NSLocalizedString("create.summary", comment: ""))
                .font(CTTypography.headline)
                .foregroundStyle(CTColors.textPrimary)
            
            Divider()
            
            CTInfoRow(label: "Name", value: tunnelName)
            CTInfoRow(label: "Protocol", value: selectedProtocol.displayName)
            CTInfoRow(label: "Port", value: port, isMono: true)
            if !hostname.isEmpty {
                CTInfoRow(label: "Hostname", value: hostname, isMono: true)
            }
        }
        .padding(CTSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(CTColors.brand.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                        .stroke(CTColors.brand.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Create Action
    func createTunnel() {
        guard isValid, let portNum = Int(port) else { return }
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let tunnel = try await tunnelService.createTunnel(
                    name: tunnelName,
                    hostname: hostname,
                    port: portNum,
                    protocol: selectedProtocol
                )
                
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
