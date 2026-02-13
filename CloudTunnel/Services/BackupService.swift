// MARK: - Backup Service
// Create, restore, export, and import backups

import Foundation
import SwiftUI

@MainActor
final class BackupService: ObservableObject {
    static let shared = BackupService()
    
    @Published var backups: [BackupFile] = []
    @Published var isProcessing = false
    @AppStorage("autoBackup") var autoBackup = false
    @AppStorage("autoBackupInterval") var autoBackupInterval: Double = 24 // hours
    
    private let backupDir: URL
    private var autoBackupTimer: Timer?
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        backupDir = appSupport.appendingPathComponent("CloudTunnel/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        loadBackupList()
        
        if autoBackup { startAutoBackup() }
    }
    
    /// Call when user toggles auto-backup on/off or changes interval
    func updateAutoBackup() {
        stopAutoBackup()
        if autoBackup {
            startAutoBackup()
        }
    }
    
    // MARK: - Create Backup
    func createBackup(name: String? = nil) async throws -> BackupFile {
        isProcessing = true
        defer { isProcessing = false }
        
        let tunnelService = TunnelService.shared
        let mampService = MAMPService.shared
        
        let settings = BackupSettings(
            cloudflaredPath: tunnelService.cloudflaredPath,
            configDirectory: tunnelService.configDirectory,
            autoStartTunnels: tunnelService.autoStartTunnels,
            autoStartMAMP: mampService.autoStartMAMP,
            checkInterval: tunnelService.checkInterval,
            mampBasePath: mampService.mampBasePath,
            mampSitesDir: mampService.mampSitesDir,
            mampApacheConfig: mampService.mampApacheConfig,
            mampVHostConfig: mampService.mampVHostConfig,
            mampHttpdConf: mampService.mampHttpdConf
        )
        
        // Read actual config file contents
        var configFiles: [BackupConfigFile] = []
        let configDir = (tunnelService.configDirectory as NSString).expandingTildeInPath
        let fm = FileManager.default
        
        if let contents = try? fm.contentsOfDirectory(atPath: configDir) {
            for file in contents where file.hasSuffix(".yml") || file.hasSuffix(".yaml") || file.hasSuffix(".json") {
                let filePath = (configDir as NSString).appendingPathComponent(file)
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let uuid = tunnelService.managedTunnels.first { $0.configPath == filePath }?.tunnelUUID ?? ""
                    configFiles.append(BackupConfigFile(fileName: file, content: content, tunnelUUID: uuid))
                }
            }
        }
        
        // System info
        let processInfo = ProcessInfo.processInfo
        let systemVersion = "\(processInfo.operatingSystemVersionString)"
        let deviceName = Host.current().localizedName ?? processInfo.hostName
        
        let backupData = BackupData(
            version: "1.0.0",
            createdAt: Date(),
            tunnels: tunnelService.managedTunnels,
            settings: settings,
            configFiles: configFiles,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            systemVersion: systemVersion,
            deviceName: deviceName
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backupData)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = name ?? "backup_\(formatter.string(from: Date()))"
        let fileURL = backupDir.appendingPathComponent("\(fileName).json")
        
        try data.write(to: fileURL)
        
        let backupFile = BackupFile(
            id: UUID(),
            name: fileName,
            createdAt: Date(),
            size: Int64(data.count),
            tunnelCount: tunnelService.managedTunnels.count
        )
        
        backups.insert(backupFile, at: 0)
        HistoryService.shared.log(.info, .system, "Backup created: \(fileName)")
        
        return backupFile
    }
    
    // MARK: - Restore Backup
    func restoreBackup(_ backup: BackupFile) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        let fileURL = backupDir.appendingPathComponent("\(backup.name).json")
        let data = try Data(contentsOf: fileURL)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupData = try decoder.decode(BackupData.self, from: data)
        
        let tunnelService = TunnelService.shared
        let mampService = MAMPService.shared
        
        // Restore settings
        tunnelService.cloudflaredPath = backupData.settings.cloudflaredPath
        tunnelService.configDirectory = backupData.settings.configDirectory
        tunnelService.autoStartTunnels = backupData.settings.autoStartTunnels
        tunnelService.checkInterval = backupData.settings.checkInterval
        mampService.autoStartMAMP = backupData.settings.autoStartMAMP
        mampService.mampBasePath = backupData.settings.mampBasePath
        mampService.mampSitesDir = backupData.settings.mampSitesDir
        mampService.mampApacheConfig = backupData.settings.mampApacheConfig
        mampService.mampVHostConfig = backupData.settings.mampVHostConfig
        mampService.mampHttpdConf = backupData.settings.mampHttpdConf
        
        // Restore config files to disk
        if !backupData.configFiles.isEmpty {
            let configDir = (tunnelService.configDirectory as NSString).expandingTildeInPath
            let fm = FileManager.default
            try? fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
            
            var restoredCount = 0
            for configFile in backupData.configFiles {
                let destPath = (configDir as NSString).appendingPathComponent(configFile.fileName)
                // Only write if file doesn't already exist (don't overwrite current configs)
                if !fm.fileExists(atPath: destPath) {
                    try? configFile.content.write(toFile: destPath, atomically: true, encoding: .utf8)
                    restoredCount += 1
                }
            }
            
            if restoredCount > 0 {
                HistoryService.shared.log(.info, .system, "Restored \(restoredCount) config files from backup")
            }
        }
        
        // Rescan config files
        tunnelService.scanConfigFiles()
        
        HistoryService.shared.log(.info, .system, "Backup restored: \(backup.name)")
    }
    
    // MARK: - Export Backup
    func exportBackup(_ backup: BackupFile) async throws -> URL {
        let sourceURL = backupDir.appendingPathComponent("\(backup.name).json")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "Backup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Backup file not found"])
        }
        return sourceURL
    }
    
    // MARK: - Import Backup
    func importBackup(from url: URL) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        let data = try Data(contentsOf: url)
        
        // Validate
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupData = try decoder.decode(BackupData.self, from: data)
        
        let fileName = url.deletingPathExtension().lastPathComponent
        let destURL = backupDir.appendingPathComponent("\(fileName).json")
        try data.write(to: destURL)
        
        let backupFile = BackupFile(
            id: UUID(),
            name: fileName,
            createdAt: backupData.createdAt,
            size: Int64(data.count),
            tunnelCount: backupData.tunnels.count
        )
        
        backups.insert(backupFile, at: 0)
        HistoryService.shared.log(.info, .system, "Backup imported: \(fileName)")
    }
    
    // MARK: - Delete Backup
    func deleteBackup(_ backup: BackupFile) {
        let fileURL = backupDir.appendingPathComponent("\(backup.name).json")
        try? FileManager.default.removeItem(at: fileURL)
        backups.removeAll { $0.id == backup.id }
    }
    
    // MARK: - Load List
    private func loadBackupList() {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        
        backups = contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> BackupFile? in
                let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let name = url.deletingPathExtension().lastPathComponent
                
                // Try to get tunnel count
                var tunnelCount = 0
                if let data = try? Data(contentsOf: url),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tunnels = json["tunnels"] as? [[String: Any]] {
                    tunnelCount = tunnels.count
                }
                
                return BackupFile(
                    id: UUID(),
                    name: name,
                    createdAt: attrs?.contentModificationDate ?? Date(),
                    size: Int64(attrs?.fileSize ?? 0),
                    tunnelCount: tunnelCount
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Auto Backup
    private func startAutoBackup() {
        autoBackupTimer?.invalidate()
        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: autoBackupInterval * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                _ = try? await self?.createBackup(name: "auto_backup")
            }
        }
    }
    
    private func stopAutoBackup() {
        autoBackupTimer?.invalidate()
        autoBackupTimer = nil
    }
}
