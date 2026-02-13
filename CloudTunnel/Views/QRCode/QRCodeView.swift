// MARK: - QR Code View
// Generates and displays QR codes for active tunnel URLs

import SwiftUI

struct QRCodeView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @State private var selectedTunnelID: UUID?
    @State private var qrImage: NSImage?
    @State private var qrURL: String = ""
    @State private var showCopied = false
    @State private var customURL: String = ""
    @State private var useCustomURL = false
    @State private var qrSize: CGFloat = 280
    
    private let qrService = QRCodeService.shared
    
    var activeTunnels: [(id: UUID, name: String, url: String)] {
        var results: [(id: UUID, name: String, url: String)] = []
        
        // Managed tunnels - running ones with hostname or config
        for tunnel in tunnelService.managedTunnels where tunnel.status == .running {
            if !tunnel.hostname.isEmpty {
                let proto = tunnel.tunnelProtocol == .https ? "https" : "https"
                let url = "\(proto)://\(tunnel.hostname)"
                results.append((tunnel.id, tunnel.displayName, url))
            } else {
                // Include with localhost URL as fallback
                let url = "http://localhost:\(tunnel.port)"
                results.append((tunnel.id, tunnel.displayName, url))
            }
        }
        
        // Quick tunnels with public URL
        for tunnel in tunnelService.quickTunnels where tunnel.status == .running {
            if let publicURL = tunnel.publicURL {
                results.append((tunnel.id, tunnel.displayName, publicURL))
            }
        }
        
        return results
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: CTSpacing.xl) {
                headerSection
                
                if activeTunnels.isEmpty && !useCustomURL {
                    emptyState
                } else {
                    HStack(alignment: .top, spacing: CTSpacing.xl) {
                        // Left: Tunnel selection + custom URL
                        VStack(spacing: CTSpacing.lg) {
                            tunnelSelector
                            customURLSection
                        }
                        .frame(maxWidth: 340)
                        
                        // Right: QR Code display
                        qrCodeDisplay
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(CTSpacing.xl)
        }
        .background(CTColors.Surface.primary)
        // Periodically refresh tunnel list
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            refreshSelection()
        }
        .onChange(of: selectedTunnelID) { _, newID in
            if let newID, let tunnel = activeTunnels.first(where: { $0.id == newID }) {
                qrURL = tunnel.url
                generateQR()
            }
        }
        .onChange(of: tunnelService.managedTunnels.count) { _, _ in
            refreshSelection()
        }
        .onChange(of: tunnelService.quickTunnels.count) { _, _ in
            refreshSelection()
        }
        .onAppear {
            refreshSelection()
        }
    }
    
    private func refreshSelection() {
        let tunnels = activeTunnels
        if tunnels.isEmpty {
            selectedTunnelID = nil
            if !useCustomURL { qrImage = nil }
            return
        }
        // If no selection yet or current selection is gone, pick first
        if selectedTunnelID == nil || !tunnels.contains(where: { $0.id == selectedTunnelID }) {
            if !useCustomURL {
                selectedTunnelID = tunnels.first?.id
                qrURL = tunnels.first?.url ?? ""
                generateQR()
            }
        }
    }
    
    // MARK: - Header
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: CTSpacing.xs) {
                Text("QR Kod Üretici")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("Tünel URL'lerini QR koda dönüştür, telefondan hızlıca test et")
                    .font(CTTypography.body)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "qrcode")
                .font(.system(size: 32))
                .foregroundStyle(CTColors.brand)
        }
    }
    
    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: CTSpacing.lg) {
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(CTColors.textTertiary)
            
            Text("Aktif Tünel Yok")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CTColors.textPrimary)
            
            Text("QR kod oluşturmak için bir tünel başlatın veya özel URL girin")
                .font(CTTypography.body)
                .foregroundStyle(CTColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                useCustomURL = true
            } label: {
                Label("Özel URL Gir", systemImage: "link")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(CTColors.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CTSpacing.xxxl)
    }
    
    // MARK: - Tunnel Selector
    var tunnelSelector: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            Text("Aktif Tüneller")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CTColors.textSecondary)
            
            if activeTunnels.isEmpty {
                HStack(spacing: CTSpacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(CTColors.warning)
                    Text("Çalışan tünel yok")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                }
                .padding(CTSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CTColors.Surface.secondary)
                .clipShape(RoundedRectangle(cornerRadius: CTRadius.md))
            } else {
                VStack(spacing: CTSpacing.xs) {
                    ForEach(activeTunnels, id: \.id) { tunnel in
                        Button {
                            useCustomURL = false
                            selectedTunnelID = tunnel.id
                            qrURL = tunnel.url
                            generateQR()
                        } label: {
                            HStack(spacing: CTSpacing.sm) {
                                Image(systemName: selectedTunnelID == tunnel.id && !useCustomURL ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedTunnelID == tunnel.id && !useCustomURL ? CTColors.brand : CTColors.textTertiary)
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tunnel.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(CTColors.textPrimary)
                                    
                                    Text(tunnel.url)
                                        .font(CTTypography.caption)
                                        .foregroundStyle(CTColors.textTertiary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Circle()
                                    .fill(CTColors.success)
                                    .frame(width: 7, height: 7)
                            }
                            .padding(CTSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CTRadius.sm)
                                    .fill(selectedTunnelID == tunnel.id && !useCustomURL ? CTColors.brand.opacity(0.1) : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CTSpacing.xs)
                .background(CTColors.Surface.secondary)
                .clipShape(RoundedRectangle(cornerRadius: CTRadius.md))
            }
        }
    }
    
    // MARK: - Custom URL
    var customURLSection: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            Text("Özel URL")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CTColors.textSecondary)
            
            VStack(spacing: CTSpacing.sm) {
                TextField("https://example.com", text: $customURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                
                Button {
                    if !customURL.isEmpty {
                        useCustomURL = true
                        qrURL = customURL
                        generateQR()
                    }
                } label: {
                    Label("QR Kod Oluştur", systemImage: "qrcode")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CTColors.brand)
                .disabled(customURL.isEmpty)
            }
            .padding(CTSpacing.md)
            .background(CTColors.Surface.secondary)
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.md))
        }
    }
    
    // MARK: - QR Code Display
    var qrCodeDisplay: some View {
        VStack(spacing: CTSpacing.lg) {
            if let qrImage {
                // QR image
                VStack(spacing: CTSpacing.md) {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: qrSize, height: qrSize)
                        .padding(CTSpacing.lg)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: CTRadius.lg))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    
                    // URL label
                    Text(qrURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(CTColors.textSecondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    
                    // Size slider
                    HStack(spacing: CTSpacing.sm) {
                        Text("Boyut")
                            .font(CTTypography.caption)
                            .foregroundStyle(CTColors.textTertiary)
                        
                        Slider(value: $qrSize, in: 150...400, step: 10) {
                            Text("QR Boyut")
                        }
                        .frame(maxWidth: 200)
                        .onChange(of: qrSize) { _, _ in
                            generateQR()
                        }
                        
                        Text("\(Int(qrSize))px")
                            .font(CTTypography.caption)
                            .foregroundStyle(CTColors.textTertiary)
                            .frame(width: 40)
                    }
                }
                
                Divider()
                
                // Actions
                HStack(spacing: CTSpacing.md) {
                    Button {
                        qrService.copyToClipboard(qrImage)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    } label: {
                        Label(showCopied ? "Kopyalandı!" : "Kopyala", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        saveQRCode(qrImage)
                    } label: {
                        Label("PNG Kaydet", systemImage: "arrow.down.doc")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(qrURL, forType: .string)
                    } label: {
                        Label("URL Kopyala", systemImage: "link")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: CTSpacing.md) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(CTColors.textTertiary)
                    
                    Text("Bir tünel seçin veya URL girin")
                        .font(CTTypography.body)
                        .foregroundStyle(CTColors.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .padding(CTSpacing.lg)
        .background(CTColors.Surface.secondary)
        .clipShape(RoundedRectangle(cornerRadius: CTRadius.lg))
    }
    
    // MARK: - Actions
    private func generateQR() {
        guard !qrURL.isEmpty else {
            qrImage = nil
            return
        }
        qrImage = qrService.generateQRCode(from: qrURL, size: qrSize)
    }
    
    private func saveQRCode(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "cloudtunnel-qr.png"
        panel.title = "QR Kodu Kaydet"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }
}

#Preview {
    QRCodeView()
        .environmentObject(TunnelService.shared)
        .frame(width: 800, height: 600)
}
