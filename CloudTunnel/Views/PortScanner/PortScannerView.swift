// MARK: - Port Scanner View
// Discovers running services on local ports with quick tunnel creation

import SwiftUI

struct PortScannerView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @StateObject private var scanner = PortScannerService.shared
    @State private var selectedPort: PortScannerService.DiscoveredPort?
    @State private var showCreateTunnel = false
    @State private var tunnelHostname = ""
    @State private var creatingTunnel = false
    @State private var filterText = ""
    
    var filteredPorts: [PortScannerService.DiscoveredPort] {
        if filterText.isEmpty { return scanner.discoveredPorts }
        return scanner.discoveredPorts.filter {
            $0.serviceName.localizedCaseInsensitiveContains(filterText) ||
            $0.processName.localizedCaseInsensitiveContains(filterText) ||
            "\($0.port)".contains(filterText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, CTSpacing.lg)
                .padding(.top, CTSpacing.lg)
                .padding(.bottom, CTSpacing.md)
            
            Divider()
            
            // Content
            if scanner.isScanning {
                scanningView
            } else if scanner.discoveredPorts.isEmpty {
                emptyState
            } else {
                // Search bar + results
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, CTSpacing.lg)
                        .padding(.vertical, CTSpacing.sm)
                    
                    Divider()
                    
                    portList
                }
            }
        }
        .background(CTColors.Surface.primary)
        .sheet(isPresented: $showCreateTunnel) {
            if let port = selectedPort {
                createTunnelSheet(port)
            }
        }
        .onAppear {
            if scanner.discoveredPorts.isEmpty {
                Task { await scanner.scanPorts() }
            }
        }
    }
    
    // MARK: - Header
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: CTSpacing.xs) {
                Text("Port Tarayıcı")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("Yerelde çalışan servisleri keşfet, tek tıkla tünel oluştur")
                    .font(CTTypography.body)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: CTSpacing.xs) {
                Button {
                    Task { await scanner.scanPorts() }
                } label: {
                    Label("Tara", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(CTColors.brand)
                .disabled(scanner.isScanning)
                
                if let lastScan = scanner.lastScanDate {
                    Text("Son tarama: \(lastScan, format: .dateTime.hour().minute())")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                }
            }
        }
    }
    
    // MARK: - Scanning View
    var scanningView: some View {
        VStack(spacing: CTSpacing.lg) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Portlar taranıyor...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CTColors.textPrimary)
            
            Text("lsof ile açık TCP portları aranıyor")
                .font(CTTypography.body)
                .foregroundStyle(CTColors.textTertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: CTSpacing.lg) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(CTColors.textTertiary)
            
            Text("Henüz Taranmadı")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CTColors.textPrimary)
            
            Text("Yerel portları tarayarak çalışan servisleri keşfedin")
                .font(CTTypography.body)
                .foregroundStyle(CTColors.textSecondary)
            
            Button {
                Task { await scanner.scanPorts() }
            } label: {
                Label("Portları Tara", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(CTColors.brand)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Bar
    var searchBar: some View {
        HStack(spacing: CTSpacing.md) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(CTColors.textTertiary)
                
                TextField("Port veya servis ara...", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(CTColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CTSpacing.sm)
            .padding(.vertical, 6)
            .background(CTColors.Surface.secondary)
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm))
            
            Spacer()
            
            Text("\(filteredPorts.count) port bulundu")
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textTertiary)
        }
    }
    
    // MARK: - Port List
    var portList: some View {
        ScrollView {
            LazyVStack(spacing: CTSpacing.sm) {
                ForEach(filteredPorts) { port in
                    portRow(port)
                }
            }
            .padding(CTSpacing.lg)
        }
    }
    
    // MARK: - Port Row
    func portRow(_ port: PortScannerService.DiscoveredPort) -> some View {
        HStack(spacing: CTSpacing.md) {
            // Service icon
            ZStack {
                RoundedRectangle(cornerRadius: CTRadius.sm)
                    .fill(port.serviceColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: port.serviceIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(port.serviceColor)
            }
            
            // Service info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: CTSpacing.sm) {
                    Text(port.serviceName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text(":\(port.port)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(CTColors.brand)
                }
                
                HStack(spacing: CTSpacing.sm) {
                    Text("PID: \(port.pid)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CTColors.textTertiary)
                    
                    Text("•")
                        .foregroundStyle(CTColors.textTertiary)
                    
                    Text(port.type.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CTColors.textTertiary)
                    
                    Text("•")
                        .foregroundStyle(CTColors.textTertiary)
                    
                    Text(port.user)
                        .font(.system(size: 11))
                        .foregroundStyle(CTColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Protocol badge
            Text(port.suggestedProtocol.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(CTColors.info)
                .clipShape(Capsule())
            
            // Quick tunnel button
            Button {
                Task {
                    let url = "http://localhost:\(port.port)"
                    _ = await tunnelService.startQuickTunnel(localURL: url)
                }
            } label: {
                Label("Hızlı Tünel", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(CTColors.warning)
            
            // Create managed tunnel
            Button {
                selectedPort = port
                showCreateTunnel = true
            } label: {
                Label("Tünel Oluştur", systemImage: "plus.circle.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(CTColors.brand)
        }
        .padding(CTSpacing.md)
        .background(CTColors.Surface.secondary)
        .clipShape(RoundedRectangle(cornerRadius: CTRadius.md))
    }
    
    // MARK: - Create Tunnel Sheet
    func createTunnelSheet(_ port: PortScannerService.DiscoveredPort) -> some View {
        VStack(spacing: CTSpacing.lg) {
            // Header
            HStack {
                Text("Tünel Oluştur")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("İptal") { showCreateTunnel = false }
                    .buttonStyle(.plain)
            }
            
            Divider()
            
            // Port info
            HStack(spacing: CTSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: CTRadius.sm)
                        .fill(port.serviceColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: port.serviceIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(port.serviceColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(port.serviceName)
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text("localhost:\(port.port) • \(port.suggestedProtocol.displayName)")
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                }
                
                Spacer()
            }
            .padding(CTSpacing.md)
            .background(CTColors.Surface.secondary)
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.md))
            
            // Hostname input
            VStack(alignment: .leading, spacing: CTSpacing.sm) {
                Text("Hostname")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CTColors.textSecondary)
                
                TextField("my-app.example.com", text: $tunnelHostname)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            
            Spacer()
            
            // Create button
            Button {
                Task {
                    creatingTunnel = true
                    defer { creatingTunnel = false }
                    
                    let _ = try? await tunnelService.createTunnel(
                        name: "\(port.serviceName)-\(port.port)",
                        hostname: tunnelHostname,
                        port: port.port,
                        protocol: port.suggestedProtocol
                    )
                    showCreateTunnel = false
                    tunnelHostname = ""
                }
            } label: {
                if creatingTunnel {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Label("Tünel Oluştur", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(CTColors.brand)
            .disabled(tunnelHostname.isEmpty || creatingTunnel)
        }
        .padding(CTSpacing.xl)
        .frame(width: 420, height: 380)
    }
}

#Preview {
    PortScannerView()
        .environmentObject(TunnelService.shared)
        .frame(width: 900, height: 600)
}
