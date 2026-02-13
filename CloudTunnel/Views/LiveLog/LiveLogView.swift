// MARK: - Live Log View
// Real-time terminal-like log viewer for cloudflared tunnel output

import SwiftUI

struct LiveLogView: View {
    @EnvironmentObject var tunnelService: TunnelService
    @StateObject private var logService = LiveLogService.shared
    @State private var scrollProxy: ScrollViewProxy?
    @Namespace private var bottomID
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, CTSpacing.lg)
                .padding(.top, CTSpacing.lg)
                .padding(.bottom, CTSpacing.md)
            
            Divider()
            
            // Toolbar
            logToolbar
                .padding(.horizontal, CTSpacing.lg)
                .padding(.vertical, CTSpacing.sm)
            
            Divider()
            
            // Log content
            if logService.filteredLogs.isEmpty {
                emptyState
            } else {
                logContent
            }
            
            // Status bar
            statusBar
        }
        .background(CTColors.Surface.primary)
    }
    
    // MARK: - Header
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: CTSpacing.xs) {
                Text("Canlı Log Viewer")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(CTColors.textPrimary)
                
                Text("cloudflared çıktısını gerçek zamanlı izleyin")
                    .font(CTTypography.body)
                    .foregroundStyle(CTColors.textSecondary)
            }
            
            Spacer()
            
            // Streaming indicator
            if logService.isStreaming {
                HStack(spacing: CTSpacing.xs) {
                    Circle()
                        .fill(logService.isPaused ? CTColors.warning : CTColors.danger)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(CTColors.danger.opacity(0.4))
                                .frame(width: 16, height: 16)
                                .opacity(logService.isPaused ? 0 : 1)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: logService.isStreaming)
                        )
                    
                    Text(logService.isPaused ? "Duraklatıldı" : "Canlı")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(logService.isPaused ? CTColors.warning : CTColors.danger)
                }
                .padding(.horizontal, CTSpacing.md)
                .padding(.vertical, CTSpacing.xs)
                .background(
                    Capsule()
                        .fill((logService.isPaused ? CTColors.warning : CTColors.danger).opacity(0.15))
                )
            }
        }
    }
    
    // MARK: - Toolbar
    var logToolbar: some View {
        HStack(spacing: CTSpacing.md) {
            // Tunnel filter
            Menu {
                Button("Tüm Tüneller") {
                    logService.selectedTunnelID = nil
                    logService.refreshVisibleLogs()
                }
                
                Divider()
                
                ForEach(tunnelService.managedTunnels.filter({ $0.status == .running })) { tunnel in
                    Button(tunnel.displayName) {
                        logService.selectedTunnelID = tunnel.id
                        logService.refreshVisibleLogs()
                    }
                }
                
                ForEach(tunnelService.quickTunnels.filter({ $0.status == .running }), id: \.id) { tunnel in
                    Button(tunnel.displayName) {
                        logService.selectedTunnelID = tunnel.id
                        logService.refreshVisibleLogs()
                    }
                }
            } label: {
                Label(
                    logService.selectedTunnelID == nil ? "Tüm Tüneller" : "Filtreleniyor",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 140)
            
            // Level filter
            Menu {
                Button("Tüm Seviyeler") {
                    logService.filterLevel = nil
                }
                Divider()
                ForEach(LiveLogService.LiveLogLevel.allCases, id: \.self) { level in
                    Button {
                        logService.filterLevel = level
                    } label: {
                        Label(level.rawValue.uppercased(), systemImage: level.icon)
                    }
                }
            } label: {
                Label(
                    logService.filterLevel?.rawValue.uppercased() ?? "Seviye",
                    systemImage: "tag"
                )
                .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(CTColors.textTertiary)
                
                TextField("Log ara...", text: $logService.filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !logService.filterText.isEmpty {
                    Button {
                        logService.filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(CTColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CTSpacing.sm)
            .padding(.vertical, 5)
            .background(CTColors.Surface.secondary)
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm))
            .frame(maxWidth: 250)
            
            Spacer()
            
            // Controls
            HStack(spacing: CTSpacing.sm) {
                // Auto-scroll toggle
                Toggle(isOn: $logService.autoScroll) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 12))
                }
                .toggleStyle(.button)
                .help("Otomatik kaydırma")
                
                // Pause/Resume
                Button {
                    logService.isPaused.toggle()
                } label: {
                    Image(systemName: logService.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12))
                }
                .help(logService.isPaused ? "Devam et" : "Duraklat")
                
                Divider()
                    .frame(height: 16)
                
                // Clear
                Button {
                    logService.clearLogs()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .help("Logları temizle")
                
                // Export
                Button {
                    exportLogs()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .help("Logları dışa aktar")
            }
        }
    }
    
    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: CTSpacing.lg) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(CTColors.textTertiary)
            
            Text("Log Yok")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CTColors.textPrimary)
            
            Text(logService.isStreaming
                 ? "Çalışan tünellerden log bekleniyor..."
                 : "Logları görmek için bir tünel başlatın")
                .font(CTTypography.body)
                .foregroundStyle(CTColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Log Content
    var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(logService.filteredLogs) { line in
                        logLineView(line)
                            .id(line.id)
                    }
                    
                    // Scroll anchor
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, CTSpacing.md)
                .padding(.vertical, CTSpacing.xs)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
            .font(.system(size: 12, design: .monospaced))
            .onChange(of: logService.filteredLogs.count) { _, _ in
                if logService.autoScroll {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }
    
    // MARK: - Log Line
    func logLineView(_ line: LiveLogService.LiveLogLine) -> some View {
        HStack(alignment: .top, spacing: CTSpacing.sm) {
            // Timestamp
            Text(line.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                .foregroundStyle(CTColors.textTertiary)
                .frame(width: 90, alignment: .leading)
            
            // Level badge
            Text(line.level.rawValue.prefix(3).uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(line.level.color)
                .frame(width: 32)
            
            // Tunnel name (if showing all)
            if logService.selectedTunnelID == nil {
                Text(line.tunnelName)
                    .foregroundStyle(CTColors.brand)
                    .frame(width: 100, alignment: .leading)
                    .lineLimit(1)
            }
            
            // Message
            Text(line.message)
                .foregroundStyle(line.level == .error ? CTColors.danger : CTColors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, CTSpacing.xs)
        .background(
            line.level == .error
                ? CTColors.danger.opacity(0.05)
                : line.level == .warning
                    ? CTColors.warning.opacity(0.03)
                    : .clear
        )
    }
    
    // MARK: - Status Bar
    var statusBar: some View {
        HStack(spacing: CTSpacing.md) {
            Divider().frame(height: 1)
            
            Text("\(logService.filteredLogs.count) satır")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CTColors.textTertiary)
            
            if logService.filterLevel != nil || !logService.filterText.isEmpty {
                Text("(filtreleniyor)")
                    .font(.system(size: 11))
                    .foregroundStyle(CTColors.warning)
            }
            
            Spacer()
            
            Text("Max: \(logService.maxLines) satır")
                .font(.system(size: 11))
                .foregroundStyle(CTColors.textTertiary)
        }
        .padding(.horizontal, CTSpacing.lg)
        .padding(.vertical, CTSpacing.xs)
        .background(CTColors.Surface.secondary)
    }
    
    // MARK: - Export
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "cloudtunnel-logs-\(Date().ISO8601Format()).txt"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let content = logService.filteredLogs.map { line in
                "[\(line.timestamp.ISO8601Format())] [\(line.level.rawValue.uppercased())] [\(line.tunnelName)] \(line.message)"
            }.joined(separator: "\n")
            
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

#Preview {
    LiveLogView()
        .environmentObject(TunnelService.shared)
        .frame(width: 900, height: 600)
}
