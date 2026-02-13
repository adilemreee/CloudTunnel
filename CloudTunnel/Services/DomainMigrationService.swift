// MARK: - Domain Migration Service
// Scans and updates domain/hostname references across all config locations

import Foundation
import SwiftUI

@MainActor
final class DomainMigrationService: ObservableObject {
    
    // MARK: - Types
    
    /// A single location where a domain was found
    struct DomainOccurrence: Identifiable, Hashable {
        let id = UUID()
        let location: LocationType
        let filePath: String
        let linePreview: String  // Snippet showing context
        let domain: String
        
        enum LocationType: String, Hashable {
            case tunnelConfig = "Tunnel Config (.yml)"
            case vhostConfig = "Apache VHost"
            case hostsFile = "/etc/hosts"
            case tunnelModel = "Tunnel (in-memory)"
            case dnsRoute = "Cloudflare DNS"
            
            var icon: String {
                switch self {
                case .tunnelConfig: return "doc.text"
                case .vhostConfig: return "server.rack"
                case .hostsFile: return "network"
                case .tunnelModel: return "point.3.connected.trianglepath.dotted"
                case .dnsRoute: return "globe"
                }
            }
        }
    }
    
    /// Result of a migration operation on a single file
    struct MigrationResult: Identifiable {
        let id = UUID()
        let location: DomainOccurrence.LocationType
        let filePath: String
        let success: Bool
        let message: String
    }
    
    // MARK: - Published State
    @Published var isScanning = false
    @Published var isMigrating = false
    @Published var occurrences: [DomainOccurrence] = []
    @Published var migrationResults: [MigrationResult] = []
    @Published var allDomains: [String] = []  // Unique domains found
    
    // MARK: - Scan All Locations
    
    /// Scans tunnel configs, VHost config, /etc/hosts, and in-memory tunnels for all domain references
    func scanAllDomains() {
        isScanning = true
        occurrences = []
        allDomains = []
        
        var found: [DomainOccurrence] = []
        
        // 1. Scan tunnel config files (.yml/.yaml)
        found += scanTunnelConfigs()
        
        // 2. Scan VHost config
        found += scanVHostConfig()
        
        // 3. Scan /etc/hosts
        found += scanHostsFile()
        
        // 4. Scan in-memory tunnel models
        found += scanTunnelModels()
        
        occurrences = found
        
        // Extract unique domains
        let domains = Set(found.map { $0.domain }).sorted()
        allDomains = domains
        
        isScanning = false
        HistoryService.shared.log(.info, .system, "Domain scan: found \(found.count) occurrences across \(domains.count) unique domains")
    }
    
    // MARK: - Migrate Domain
    
    /// Replace oldDomain with newDomain in ALL locations where it was found
    func migrateDomain(from oldDomain: String, to newDomain: String, updateDNS: Bool = true) async -> [MigrationResult] {
        guard !oldDomain.isEmpty, !newDomain.isEmpty, oldDomain != newDomain else { return [] }
        
        isMigrating = true
        migrationResults = []
        var results: [MigrationResult] = []
        
        let relevantOccurrences = occurrences.filter { $0.domain == oldDomain }
        
        // Group by location type to avoid duplicate file writes
        let configPaths = Set(relevantOccurrences.filter { $0.location == .tunnelConfig }.map { $0.filePath })
        let vhostPaths = Set(relevantOccurrences.filter { $0.location == .vhostConfig }.map { $0.filePath })
        let hostsPaths = Set(relevantOccurrences.filter { $0.location == .hostsFile }.map { $0.filePath })
        let tunnelModels = relevantOccurrences.filter { $0.location == .tunnelModel }
        
        // 1. Update tunnel config files
        for path in configPaths {
            let result = updateFileContent(path: path, oldDomain: oldDomain, newDomain: newDomain, type: .tunnelConfig)
            results.append(result)
        }
        
        // 2. Update VHost config
        for path in vhostPaths {
            let result = updateFileContent(path: path, oldDomain: oldDomain, newDomain: newDomain, type: .vhostConfig)
            results.append(result)
        }
        
        // 3. Update /etc/hosts (requires sudo)
        for path in hostsPaths {
            let result = updateHostsFile(path: path, oldDomain: oldDomain, newDomain: newDomain)
            results.append(result)
        }
        
        // 4. Update in-memory tunnel models
        for occurrence in tunnelModels {
            let tunnelService = TunnelService.shared
            for i in tunnelService.managedTunnels.indices {
                if tunnelService.managedTunnels[i].hostname == oldDomain {
                    tunnelService.managedTunnels[i].hostname = newDomain
                }
            }
            results.append(MigrationResult(
                location: .tunnelModel, filePath: "memory",
                success: true, message: "Tünel hostname güncellendi"
            ))
        }
        
        // 5. Update Cloudflare DNS route (if requested and logged in)
        if updateDNS && TunnelService.shared.isLoggedIn {
            // Find the tunnel UUID for the old domain
            if let tunnel = TunnelService.shared.managedTunnels.first(where: { $0.hostname == newDomain || $0.hostname == oldDomain }),
               !tunnel.tunnelUUID.isEmpty {
                do {
                    try await TunnelService.shared.routeDNS(tunnelID: tunnel.tunnelUUID, hostname: newDomain)
                    results.append(MigrationResult(
                        location: .dnsRoute, filePath: "cloudflare",
                        success: true, message: "DNS yönlendirmesi güncellendi: \(newDomain)"
                    ))
                } catch {
                    results.append(MigrationResult(
                        location: .dnsRoute, filePath: "cloudflare",
                        success: false, message: "DNS güncelleme hatası: \(error.localizedDescription)"
                    ))
                }
            }
        }
        
        migrationResults = results
        isMigrating = false
        
        let successCount = results.filter { $0.success }.count
        HistoryService.shared.log(.info, .system, "Domain migration: \(oldDomain) → \(newDomain) (\(successCount)/\(results.count) başarılı)")
        
        // Re-scan to update the list
        scanAllDomains()
        
        // Re-scan tunnel configs so the tunnel list updates
        TunnelService.shared.scanConfigFiles()
        MAMPService.shared.scanSites()
        
        return results
    }
    
    // MARK: - Private Scanners
    
    private func scanTunnelConfigs() -> [DomainOccurrence] {
        var found: [DomainOccurrence] = []
        let configDir = (TunnelService.shared.configDirectory as NSString).expandingTildeInPath
        let fm = FileManager.default
        
        guard let contents = try? fm.contentsOfDirectory(atPath: configDir) else { return [] }
        
        for file in contents where file.hasSuffix(".yml") || file.hasSuffix(".yaml") {
            let filePath = (configDir as NSString).appendingPathComponent(file)
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
            
            // Find hostname: values
            let hostnamePattern = #"(?m)^\s*-?\s*hostname:\s*(\S+)"#
            if let regex = try? NSRegularExpression(pattern: hostnamePattern),
               let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)),
               match.numberOfRanges >= 2 {
                let domain = (content as NSString).substring(with: match.range(at: 1))
                if !domain.isEmpty && domain != "\"\"" {
                    let lineStart = (content as NSString).lineRange(for: match.range).location
                    let lineRange = (content as NSString).lineRange(for: match.range)
                    let linePreview = (content as NSString).substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    found.append(DomainOccurrence(
                        location: .tunnelConfig,
                        filePath: filePath,
                        linePreview: linePreview,
                        domain: domain
                    ))
                }
            }
        }
        
        return found
    }
    
    private func scanVHostConfig() -> [DomainOccurrence] {
        var found: [DomainOccurrence] = []
        let vhostPath = MAMPService.shared.mampVHostConfig
        
        guard let content = try? String(contentsOfFile: vhostPath, encoding: .utf8) else { return [] }
        
        // Find all ServerName values
        let pattern = #"(?m)^\s*ServerName\s+(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        
        for match in matches where match.numberOfRanges >= 2 {
            let domain = nsContent.substring(with: match.range(at: 1))
            let lineRange = nsContent.lineRange(for: match.range)
            let linePreview = nsContent.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            
            found.append(DomainOccurrence(
                location: .vhostConfig,
                filePath: vhostPath,
                linePreview: linePreview,
                domain: domain
            ))
        }
        
        // Also find comment lines referencing domains
        let commentPattern = #"(?m)#.*for\s+(\S+)\s+on\s+port"#
        if let commentRegex = try? NSRegularExpression(pattern: commentPattern) {
            let commentMatches = commentRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in commentMatches where match.numberOfRanges >= 2 {
                let domain = nsContent.substring(with: match.range(at: 1))
                // Only add if not already found via ServerName
                if !found.contains(where: { $0.domain == domain && $0.location == .vhostConfig }) {
                    let lineRange = nsContent.lineRange(for: match.range)
                    let linePreview = nsContent.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    found.append(DomainOccurrence(location: .vhostConfig, filePath: vhostPath, linePreview: linePreview, domain: domain))
                }
            }
        }
        
        return found
    }
    
    private func scanHostsFile() -> [DomainOccurrence] {
        var found: [DomainOccurrence] = []
        let hostsPath = "/etc/hosts"
        
        guard let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return [] }
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            // Parse: 127.0.0.1   domain.com
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            
            // Skip standard entries
            let standardHosts = ["localhost", "broadcasthost", "ip6-localhost", "ip6-loopback"]
            
            for i in 1..<parts.count {
                let domain = parts[i]
                if !standardHosts.contains(domain) && domain.contains(".") {
                    found.append(DomainOccurrence(
                        location: .hostsFile,
                        filePath: hostsPath,
                        linePreview: trimmed,
                        domain: domain
                    ))
                }
            }
        }
        
        return found
    }
    
    private func scanTunnelModels() -> [DomainOccurrence] {
        var found: [DomainOccurrence] = []
        
        for tunnel in TunnelService.shared.managedTunnels where !tunnel.hostname.isEmpty {
            found.append(DomainOccurrence(
                location: .tunnelModel,
                filePath: tunnel.configPath,
                linePreview: "\(tunnel.displayName) → \(tunnel.hostname):\(tunnel.port)",
                domain: tunnel.hostname
            ))
        }
        
        return found
    }
    
    // MARK: - Private Updaters
    
    private func updateFileContent(path: String, oldDomain: String, newDomain: String, type: DomainOccurrence.LocationType) -> MigrationResult {
        guard var content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return MigrationResult(location: type, filePath: path, success: false, message: "Dosya okunamadı")
        }
        
        let originalContent = content
        content = content.replacingOccurrences(of: oldDomain, with: newDomain)
        
        if content == originalContent {
            return MigrationResult(location: type, filePath: path, success: true, message: "Değişiklik gerekmedi")
        }
        
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return MigrationResult(location: type, filePath: path, success: true, message: "Güncellendi ✓")
        } catch {
            return MigrationResult(location: type, filePath: path, success: false, message: "Yazma hatası: \(error.localizedDescription)")
        }
    }
    
    private func updateHostsFile(path: String, oldDomain: String, newDomain: String) -> MigrationResult {
        // /etc/hosts requires admin privileges
        let script = """
        do shell script "sed -i '' 's/\(oldDomain)/\(newDomain)/g' \(path)" with administrator privileges
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                return MigrationResult(location: .hostsFile, filePath: path, success: true, message: "/etc/hosts güncellendi (admin)")
            } else {
                return MigrationResult(location: .hostsFile, filePath: path, success: false, message: "Admin izni reddedildi veya hata oluştu")
            }
        } catch {
            return MigrationResult(location: .hostsFile, filePath: path, success: false, message: error.localizedDescription)
        }
    }
}
