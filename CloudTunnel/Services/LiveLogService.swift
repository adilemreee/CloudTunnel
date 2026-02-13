// MARK: - Live Log Service
// Real-time log streaming from cloudflared tunnel processes

import Foundation
import SwiftUI
import Combine

@MainActor
final class LiveLogService: ObservableObject {
    static let shared = LiveLogService()
    
    // MARK: - Published State
    @Published var liveLogs: [LiveLogLine] = []
    @Published var isStreaming = false
    @Published var selectedTunnelID: UUID?
    @Published var filterText: String = ""
    @Published var filterLevel: LiveLogLevel?
    @Published var autoScroll = true
    @Published var isPaused = false
    
    @AppStorage("maxLiveLogLines") var maxLines: Int = 2000
    
    // Per-tunnel log buffers
    private var tunnelLogs: [UUID: [LiveLogLine]] = [:]
    
    // Serial queue for thread-safe log access
    private let logQueue = DispatchQueue(label: "com.cloudtunnel.livelog", qos: .userInteractive)
    
    private init() {}
    
    // MARK: - Live Log Line
    struct LiveLogLine: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let level: LiveLogLevel
        let message: String
        let tunnelName: String
        let tunnelID: UUID
        let raw: String
    }
    
    enum LiveLogLevel: String, CaseIterable {
        case info, warning, error, debug, trace
        
        var color: Color {
            switch self {
            case .info:    CTColors.info
            case .warning: CTColors.warning
            case .error:   CTColors.danger
            case .debug:   CTColors.textTertiary
            case .trace:   Color.primary.opacity(0.3)
            }
        }
        
        var icon: String {
            switch self {
            case .info:    "info.circle"
            case .warning: "exclamationmark.triangle"
            case .error:   "xmark.octagon"
            case .debug:   "ladybug"
            case .trace:   "text.alignleft"
            }
        }
    }
    
    // MARK: - Pipe Registration
    /// Called by TunnelService when a tunnel starts — registers a pipe for live streaming
    func registerPipe(_ pipe: Pipe, tunnelID: UUID, tunnelName: String) {
        tunnelLogs[tunnelID] = []
        isStreaming = true
        
        Task.detached { [weak self] in
            let handle = pipe.fileHandleForReading
            while true {
                guard let data = try? handle.availableData, !data.isEmpty else { break }
                let output = String(data: data, encoding: .utf8) ?? ""
                
                for line in output.components(separatedBy: .newlines) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let level = Self.parseLevel(line)
                    let logLine = LiveLogLine(
                        timestamp: Date(),
                        level: level,
                        message: Self.cleanMessage(line),
                        tunnelName: tunnelName,
                        tunnelID: tunnelID,
                        raw: line
                    )
                    
                    await MainActor.run {
                        self?.appendLog(logLine, tunnelID: tunnelID)
                    }
                }
            }
            
            await MainActor.run {
                self?.isStreaming = (self?.tunnelLogs.keys.count ?? 0) > 0
            }
        }
    }
    
    /// Remove tunnel logs when tunnel stops
    func unregisterTunnel(_ tunnelID: UUID) {
        tunnelLogs.removeValue(forKey: tunnelID)
        if tunnelLogs.isEmpty {
            isStreaming = false
        }
    }
    
    // MARK: - Log Management
    private func appendLog(_ line: LiveLogLine, tunnelID: UUID) {
        guard !isPaused else { return }
        
        // Add to tunnel-specific buffer
        tunnelLogs[tunnelID, default: []].append(line)
        if (tunnelLogs[tunnelID]?.count ?? 0) > maxLines {
            tunnelLogs[tunnelID] = Array(tunnelLogs[tunnelID]!.suffix(maxLines))
        }
        
        // Update visible logs
        refreshVisibleLogs()
    }
    
    func refreshVisibleLogs() {
        if let selected = selectedTunnelID {
            liveLogs = tunnelLogs[selected] ?? []
        } else {
            // Show all tunnels merged and sorted by timestamp
            liveLogs = tunnelLogs.values.flatMap { $0 }.sorted { $0.timestamp < $1.timestamp }
            if liveLogs.count > maxLines {
                liveLogs = Array(liveLogs.suffix(maxLines))
            }
        }
    }
    
    func clearLogs() {
        if let selected = selectedTunnelID {
            tunnelLogs[selected] = []
        } else {
            tunnelLogs.removeAll()
        }
        liveLogs = []
    }
    
    var filteredLogs: [LiveLogLine] {
        liveLogs.filter { line in
            if let level = filterLevel, line.level != level { return false }
            if !filterText.isEmpty {
                return line.message.localizedCaseInsensitiveContains(filterText) ||
                       line.tunnelName.localizedCaseInsensitiveContains(filterText)
            }
            return true
        }
    }
    
    var activeTunnelIDs: [UUID] {
        Array(tunnelLogs.keys)
    }
    
    // MARK: - Parsing
    nonisolated private static func parseLevel(_ line: String) -> LiveLogLevel {
        let lower = line.lowercased()
        if lower.contains("err") || lower.contains("fatal") || lower.contains("panic") {
            return .error
        } else if lower.contains("warn") {
            return .warning
        } else if lower.contains("inf") || lower.contains("connected") || lower.contains("registered") {
            return .info
        } else if lower.contains("dbg") || lower.contains("debug") {
            return .debug
        }
        return .trace
    }
    
    nonisolated private static func cleanMessage(_ line: String) -> String {
        // Remove ANSI escape codes
        var cleaned = line.replacingOccurrences(
            of: "\\x1B\\[[0-9;]*[a-zA-Z]",
            with: "",
            options: .regularExpression
        )
        // Remove timestamp prefix if present (cloudflared format: 2024-01-01T12:00:00Z)
        if let range = cleaned.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\s*"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
