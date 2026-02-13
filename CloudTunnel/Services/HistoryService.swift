// MARK: - History Service
// Centralized logging with persistence

import Foundation
import SwiftUI

@MainActor
final class HistoryService: ObservableObject {
    static let shared = HistoryService()
    
    @Published var logs: [LogEntry] = []
    @AppStorage("maxLogEntries") var maxLogEntries: Int = 1000
    
    private let logFile: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CloudTunnel", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        logFile = appDir.appendingPathComponent("history.json")
        loadLogs()
    }
    
    // MARK: - Logging
    func log(_ level: LogEntry.LogLevel, _ category: LogEntry.LogCategory, _ message: String, source: String? = nil) {
        let entry = LogEntry(level: level, category: category, message: message, source: source)
        logs.insert(entry, at: 0)
        
        // Trim
        if logs.count > maxLogEntries {
            logs = Array(logs.prefix(maxLogEntries))
        }
        
        saveLogs()
    }
    
    /// Thread-safe logging from background contexts
    nonisolated func logFromBackground(_ level: LogEntry.LogLevel, _ category: LogEntry.LogCategory, _ message: String) {
        Task { @MainActor in
            self.log(level, category, message)
        }
    }
    
    // MARK: - Filtering
    func filtered(level: LogEntry.LogLevel? = nil, category: LogEntry.LogCategory? = nil, search: String = "") -> [LogEntry] {
        logs.filter { entry in
            if let level, entry.level != level { return false }
            if let category, entry.category != category { return false }
            if !search.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(search)
            }
            return true
        }
    }
    
    // MARK: - Clear
    func clearLogs() {
        logs.removeAll()
        saveLogs()
    }
    
    func clearCategory(_ category: LogEntry.LogCategory) {
        logs.removeAll { $0.category == category }
        saveLogs()
    }
    
    // MARK: - Export
    func exportLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return logs.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue.uppercased())] [\(entry.category.displayName)] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    // MARK: - Persistence
    private func saveLogs() {
        let logsSnapshot = logs
        let file = logFile
        Task.detached {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(logsSnapshot) {
                try? data.write(to: file)
            }
        }
    }
    
    private func loadLogs() {
        guard let data = try? Data(contentsOf: logFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        logs = (try? decoder.decode([LogEntry].self, from: data)) ?? []
    }
    
    // MARK: - Stats
    var errorCount: Int { logs.filter { $0.level == .error || $0.level == .critical }.count }
    var warningCount: Int { logs.filter { $0.level == .warning }.count }
    var todayCount: Int { logs.filter { Calendar.current.isDateInToday($0.timestamp) }.count }
}
