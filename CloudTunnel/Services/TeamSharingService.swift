// MARK: - Team Sharing Service
// Export/import tunnel configurations as .cloudtunnel files

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shareable Tunnel Package
struct TunnelPackage: Codable {
    let version: String
    let exportedAt: Date
    let exportedBy: String
    let description: String
    let tunnels: [SharedTunnelConfig]
    let vhostEntries: [SharedVHostEntry]
    
    struct SharedTunnelConfig: Codable, Identifiable {
        var id: String { tunnelUUID.isEmpty ? name : tunnelUUID }
        let name: String
        let hostname: String
        let port: Int
        let tunnelProtocol: String
        let tunnelUUID: String
        let configContent: String
        let source: String
    }
    
    struct SharedVHostEntry: Codable, Identifiable {
        var id: String { "\(serverName):\(port)" }
        let serverName: String
        let port: Int
        let documentRoot: String
    }
}

// MARK: - CloudTunnel UTType
extension UTType {
    static var cloudtunnel: UTType {
        UTType(exportedAs: "com.adilemre.cloudtunnel", conformingTo: .json)
    }
}

@MainActor
final class TeamSharingService: ObservableObject {
    static let shared = TeamSharingService()
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastExportURL: URL?
    @Published var importPreview: TunnelPackage?
    @Published var importError: String?
    @Published var exportError: String?
    @Published var importResults: [ImportResult] = []
    
    struct ImportResult: Identifiable {
        let id = UUID()
        let name: String
        let success: Bool
        let message: String
    }
    
    private init() {}
    
    // MARK: - Export
    
    /// Export selected tunnels to a .cloudtunnel package
    func exportTunnels(_ tunnels: [ManagedTunnel], description: String = "", includeVHosts: Bool = true) -> TunnelPackage {
        let fm = FileManager.default
        
        let sharedTunnels = tunnels.map { tunnel -> TunnelPackage.SharedTunnelConfig in
            // Read config file content
            var configContent = ""
            if fm.fileExists(atPath: tunnel.configPath),
               let content = try? String(contentsOfFile: tunnel.configPath, encoding: .utf8) {
                // Remove credentials-file line for security
                configContent = content.components(separatedBy: .newlines)
                    .filter { !$0.contains("credentials-file") }
                    .joined(separator: "\n")
            }
            
            return TunnelPackage.SharedTunnelConfig(
                name: tunnel.name,
                hostname: tunnel.hostname,
                port: tunnel.port,
                tunnelProtocol: tunnel.tunnelProtocol.rawValue,
                tunnelUUID: tunnel.tunnelUUID,
                configContent: configContent,
                source: tunnel.source.rawValue
            )
        }
        
        // Gather VHost entries
        var vhosts: [TunnelPackage.SharedVHostEntry] = []
        if includeVHosts {
            let mampService = MAMPService.shared
            for site in mampService.sites {
                for vhost in site.vhosts {
                    vhosts.append(TunnelPackage.SharedVHostEntry(
                        serverName: vhost.serverName,
                        port: vhost.port,
                        documentRoot: vhost.documentRoot
                    ))
                }
            }
        }
        
        return TunnelPackage(
            version: "1.0",
            exportedAt: Date(),
            exportedBy: NSFullUserName(),
            description: description,
            tunnels: sharedTunnels,
            vhostEntries: vhosts
        )
    }
    
    /// Save package to file and return URL
    func savePackage(_ package: TunnelPackage, fileName: String) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(package)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(fileName).cloudtunnel")
        try data.write(to: fileURL)
        
        lastExportURL = fileURL
        return fileURL
    }
    
    /// Show save panel and export
    func exportWithSavePanel(_ tunnels: [ManagedTunnel], description: String = "", includeVHosts: Bool = true) {
        isExporting = true
        exportError = nil
        
        let package = exportTunnels(tunnels, description: description, includeVHosts: includeVHosts)
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "CloudTunnel-\(Date().formatted(.dateTime.year().month().day()))"
        panel.allowedContentTypes = [UTType(filenameExtension: "cloudtunnel") ?? .json]
        panel.title = "Tünel Konfigürasyonunu Dışa Aktar"
        panel.message = "\(package.tunnels.count) tünel konfigürasyonu dışa aktarılacak"
        
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isExporting = false }
                
                guard response == .OK, let url = panel.url else { return }
                
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(package)
                    try data.write(to: url)
                    self.lastExportURL = url
                    HistoryService.shared.log(.info, .system, "Exported \(package.tunnels.count) tunnels to \(url.lastPathComponent)")
                } catch {
                    self.exportError = error.localizedDescription
                    HistoryService.shared.log(.error, .system, "Export failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Import
    
    /// Load and preview a .cloudtunnel package
    func loadPackage(from url: URL) throws -> TunnelPackage {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TunnelPackage.self, from: data)
    }
    
    /// Show open panel and preview
    func importWithOpenPanel() {
        importError = nil
        importPreview = nil
        importResults = []
        
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "cloudtunnel") ?? .json, .json]
        panel.title = "Tünel Konfigürasyonu İçe Aktar"
        panel.message = ".cloudtunnel dosyasını seçin"
        panel.allowsMultipleSelection = false
        
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                
                do {
                    self.importPreview = try self.loadPackage(from: url)
                } catch {
                    self.importError = "Dosya okunamadı: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Apply imported tunnels
    func applyImport(selectedTunnelIDs: Set<String>, createConfigs: Bool = true) async {
        guard let package = importPreview else { return }
        isImporting = true
        importResults = []
        
        let tunnelService = TunnelService.shared
        let configDir = (tunnelService.configDirectory as NSString).expandingTildeInPath
        let fm = FileManager.default
        
        for sharedTunnel in package.tunnels {
            guard selectedTunnelIDs.contains(sharedTunnel.id) else { continue }
            
            // Check if tunnel already exists
            if tunnelService.managedTunnels.contains(where: { $0.tunnelUUID == sharedTunnel.tunnelUUID && !sharedTunnel.tunnelUUID.isEmpty }) {
                importResults.append(ImportResult(
                    name: sharedTunnel.name,
                    success: false,
                    message: "Bu tünel zaten mevcut (UUID: \(sharedTunnel.tunnelUUID.prefix(8))...)"
                ))
                continue
            }
            
            if createConfigs && !sharedTunnel.configContent.isEmpty {
                // Write config file
                let configPath = "\(configDir)/\(sharedTunnel.name).yml"
                
                do {
                    try sharedTunnel.configContent.write(toFile: configPath, atomically: true, encoding: .utf8)
                    importResults.append(ImportResult(
                        name: sharedTunnel.name,
                        success: true,
                        message: "Config dosyası oluşturuldu: \(sharedTunnel.name).yml"
                    ))
                } catch {
                    importResults.append(ImportResult(
                        name: sharedTunnel.name,
                        success: false,
                        message: "Config yazılamadı: \(error.localizedDescription)"
                    ))
                }
            } else {
                // Create tunnel via cloudflared if available
                if tunnelService.cloudflaredInstalled && tunnelService.isLoggedIn {
                    do {
                        let proto = TunnelProtocol(rawValue: sharedTunnel.tunnelProtocol) ?? .http
                        _ = try await tunnelService.createTunnel(
                            name: sharedTunnel.name,
                            hostname: sharedTunnel.hostname,
                            port: sharedTunnel.port,
                            protocol: proto
                        )
                        importResults.append(ImportResult(
                            name: sharedTunnel.name,
                            success: true,
                            message: "Tünel oluşturuldu ve DNS yönlendirildi"
                        ))
                    } catch {
                        importResults.append(ImportResult(
                            name: sharedTunnel.name,
                            success: false,
                            message: "Tünel oluşturulamadı: \(error.localizedDescription)"
                        ))
                    }
                } else {
                    importResults.append(ImportResult(
                        name: sharedTunnel.name,
                        success: false,
                        message: "Cloudflare girişi gerekli veya cloudflared yüklü değil"
                    ))
                }
            }
        }
        
        // Rescan
        tunnelService.scanConfigFiles()
        isImporting = false
        
        let successCount = importResults.filter { $0.success }.count
        HistoryService.shared.log(.info, .system, "Imported \(successCount)/\(importResults.count) tunnels from package")
    }
}
