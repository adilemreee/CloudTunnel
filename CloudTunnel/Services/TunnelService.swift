// MARK: - Tunnel Service
// Manages cloudflared tunnel processes (managed + quick)

import Foundation
import SwiftUI
import Combine

@MainActor
final class TunnelService: ObservableObject {
    static let shared = TunnelService()
    
    // MARK: - Published State
    @Published var managedTunnels: [ManagedTunnel] = []
    @Published var quickTunnels: [QuickTunnel] = []
    @Published var isScanning = false
    @Published var cloudflaredInstalled = false
    @Published var cloudflaredVersion: String?
    @Published var isLoggedIn = false
    @Published var isLoggingIn = false
    @Published var loginError: String?
    
    // MARK: - Settings
    @AppStorage("cloudflaredPath") var cloudflaredPath = ""
    @AppStorage("configDirectory") var configDirectory = "~/.cloudflared"
    @AppStorage("checkInterval") var checkInterval: Double = 15
    @AppStorage("autoStartTunnels") var autoStartTunnels = false
    
    // MARK: - Private
    private var managedProcesses: [UUID: Process] = [:]
    private var quickProcesses: [UUID: Process] = [:]
    private var statusTimer: Timer?
    private var dirMonitor: DispatchSourceFileSystemObject?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        resolveCloudflaredPath()
        checkLoginStatus()
        scanConfigFiles()
        startStatusMonitor()
        startDirectoryMonitor()
        
        if autoStartTunnels {
            Task { await startAllTunnels() }
        }
    }
    
    // MARK: - Cloudflare Login
    func cloudflareLogin() async {
        guard cloudflaredInstalled else {
            loginError = "cloudflared not installed"
            return
        }
        
        isLoggingIn = true
        loginError = nil
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cloudflaredPath)
        process.arguments = ["login"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        do {
            try process.run()
            
            // Read output in background to detect success/failure
            Task.detached { [weak self] in
                let handle = outputPipe.fileHandleForReading
                var fullOutput = ""
                
                while true {
                    guard let data = try? handle.availableData, !data.isEmpty else { break }
                    let output = String(data: data, encoding: .utf8) ?? ""
                    fullOutput += output
                    
                    if output.lowercased().contains("you have successfully logged in") ||
                       output.lowercased().contains("successfully written") ||
                       output.contains("cert.pem") {
                        await MainActor.run {
                            self?.isLoggedIn = true
                            self?.isLoggingIn = false
                            self?.loginError = nil
                        }
                        HistoryService.shared.logFromBackground(.info, .tunnel, "Cloudflare login successful")
                    }
                    
                    if output.lowercased().contains("failed") || output.lowercased().contains("error") {
                        await MainActor.run {
                            self?.loginError = output.trimmingCharacters(in: .whitespacesAndNewlines)
                            self?.isLoggingIn = false
                        }
                        HistoryService.shared.logFromBackground(.error, .tunnel, "Cloudflare login failed: \(output)")
                    }
                }
                
                await MainActor.run {
                    // If process ended without clear signals
                    if self?.isLoggingIn == true {
                        self?.isLoggingIn = false
                        self?.checkLoginStatus()
                    }
                }
            }
        } catch {
            isLoggingIn = false
            loginError = error.localizedDescription
            HistoryService.shared.log(.error, .tunnel, "Login process failed: \(error)")
        }
    }
    
    func checkLoginStatus() {
        let certPath = (configDirectory as NSString).expandingTildeInPath + "/cert.pem"
        isLoggedIn = FileManager.default.fileExists(atPath: certPath)
    }
    
    func cloudflareLogout() {
        let certPath = (configDirectory as NSString).expandingTildeInPath + "/cert.pem"
        try? FileManager.default.removeItem(atPath: certPath)
        isLoggedIn = false
        HistoryService.shared.log(.info, .tunnel, "Logged out from Cloudflare")
    }
    
    // MARK: - Cloudflared Resolution
    func resolveCloudflaredPath() {
        if !cloudflaredPath.isEmpty && FileManager.default.fileExists(atPath: cloudflaredPath) {
            checkCloudflaredVersion()
            return
        }
        
        let searchPaths = [
            "/opt/homebrew/bin/cloudflared",
            "/usr/local/bin/cloudflared",
            "/usr/bin/cloudflared",
            "\(NSHomeDirectory())/.cloudflared/bin/cloudflared"
        ]
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                cloudflaredPath = path
                checkCloudflaredVersion()
                return
            }
        }
        
        // Try which
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["cloudflared"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        
        if let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
           let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            cloudflaredPath = path
            checkCloudflaredVersion()
        }
    }
    
    private func checkCloudflaredVersion() {
        guard !cloudflaredPath.isEmpty else {
            cloudflaredInstalled = false
            return
        }
        
        Task.detached { [cloudflaredPath] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cloudflaredPath)
            process.arguments = ["version"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try? process.run()
            process.waitUntilExit()
            
            let data = try? pipe.fileHandleForReading.readDataToEndOfFile()
            let output = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            
            await MainActor.run {
                self.cloudflaredInstalled = process.terminationStatus == 0
                if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    self.cloudflaredVersion = String(output[match])
                }
            }
        }
    }
    
    // MARK: - Config Scanning
    func scanConfigFiles() {
        isScanning = true
        
        let expandedPath = (configDirectory as NSString).expandingTildeInPath
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: expandedPath) else {
            isScanning = false
            return
        }
        
        // First, resolve UUID → name mapping from cloudflared
        let cfPath = cloudflaredPath
        
        Task.detached { [expandedPath, cfPath] in
            let fm = FileManager.default
            
            // Resolve UUID → name mapping off the main thread
            let uuidNameMap = Self.resolveCloudflaredTunnelNames(cloudflaredPath: cfPath)
            guard let contents = try? fm.contentsOfDirectory(atPath: expandedPath) else {
                await MainActor.run { self.isScanning = false }
                return
            }
            
            var foundTunnels: [ManagedTunnel] = []
            
            for file in contents where file.hasSuffix(".yml") || file.hasSuffix(".yaml") {
                let filePath = (expandedPath as NSString).appendingPathComponent(file)
                guard let data = fm.contents(atPath: filePath),
                      let content = String(data: data, encoding: .utf8) else { continue }
                
                let tunnelUUID = self.parseYAMLValue(content, key: "tunnel") ?? ""
                let hostname = self.parseYAMLValue(content, key: "hostname") ?? ""
                let originStr = self.parseYAMLValue(content, key: "url") ?? self.parseYAMLValue(content, key: "service") ?? "http://localhost:80"
                let port = self.extractPort(from: originStr)
                
                // Determine a human-readable name:
                // 1. Use the config filename (without extension) if it's not a UUID
                // 2. Look up tunnel name from cloudflared tunnel list
                // 3. If hostname is available, use the first part of it
                // 4. Fall back to a shortened UUID
                let fileBaseName = (file as NSString).deletingPathExtension
                let isFileNameUUID = fileBaseName.range(of: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#, options: .regularExpression) != nil
                
                let name: String
                if !isFileNameUUID {
                    name = fileBaseName
                } else if let resolvedName = uuidNameMap[tunnelUUID], !resolvedName.isEmpty {
                    name = resolvedName
                } else if !hostname.isEmpty {
                    // Use first subdomain part of hostname: "mysite.example.com" → "mysite"
                    name = hostname.components(separatedBy: ".").first ?? hostname
                } else {
                    // Shortened UUID as last resort
                    name = String(tunnelUUID.prefix(8))
                }
                
                var tunnel = ManagedTunnel(
                    name: name,
                    configPath: filePath,
                    hostname: hostname,
                    port: port,
                    tunnelProtocol: originStr.hasPrefix("https") ? .https : .http,
                    tunnelUUID: tunnelUUID
                )
                
                // Preserve existing status if we already know about this tunnel
                await MainActor.run {
                    if let existing = self.managedTunnels.first(where: { $0.configPath == filePath }) {
                        tunnel.status = existing.status
                        tunnel.pid = existing.pid
                        tunnel.lastStarted = existing.lastStarted
                    }
                }
                
                foundTunnels.append(tunnel)
            }
            
            await MainActor.run {
                self.managedTunnels = foundTunnels
                self.isScanning = false
                HistoryService.shared.log(.info, .tunnel, "Scanned \(foundTunnels.count) config files")
            }
        }
    }
    
    // MARK: - YAML Parsing Helpers
    nonisolated private func parseYAMLValue(_ content: String, key: String) -> String? {
        let pattern = #"(?m)^\s*"# + key + #"\s*:\s*(.+)$"#
        guard let range = content.range(of: pattern, options: .regularExpression) else { return nil }
        let match = content[range]
        let parts = match.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return parts[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
    
    nonisolated private func extractPort(from urlString: String) -> Int {
        if let url = URL(string: urlString), let port = url.port { return port }
        if let range = urlString.range(of: #":(\d+)"#, options: .regularExpression) {
            let portStr = urlString[range].dropFirst()
            return Int(portStr) ?? 80
        }
        return 80
    }
    
    /// Resolve tunnel UUIDs to human-readable names via `cloudflared tunnel list`
    nonisolated static private func resolveCloudflaredTunnelNames(cloudflaredPath: String) -> [String: String] {
        var map: [String: String] = [:]
        
        guard !cloudflaredPath.isEmpty else { return map }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cloudflaredPath)
        process.arguments = ["tunnel", "list", "--output", "json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = try pipe.fileHandleForReading.readDataToEndOfFile()
            if let tunnels = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for tunnel in tunnels {
                    if let id = tunnel["id"] as? String, let name = tunnel["name"] as? String {
                        map[id] = name
                    }
                }
            }
        } catch {
            // JSON parsing failed, try parsing text output
            // Format: UUID NAME CREATED CONNECTIONS
            if let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
               let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                let uuidPattern = #"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\s+(\S+)"#
                for line in lines {
                    if let range = line.range(of: uuidPattern, options: .regularExpression) {
                        let matched = String(line[range])
                        let parts = matched.split(separator: " ", maxSplits: 1)
                        if parts.count == 2 {
                            map[String(parts[0])] = String(parts[1])
                        }
                    }
                }
            }
        }
        
        return map
    }
    
    // MARK: - Managed Tunnel Actions
    func startTunnel(_ tunnel: ManagedTunnel) async {
        guard cloudflaredInstalled else {
            HistoryService.shared.log(.error, .tunnel, "cloudflared not installed")
            return
        }
        
        guard let index = managedTunnels.firstIndex(where: { $0.id == tunnel.id }) else { return }
        managedTunnels[index].status = .starting
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cloudflaredPath)
        process.arguments = ["tunnel", "--config", tunnel.configPath, "run"]
        
        if !tunnel.tunnelUUID.isEmpty {
            process.arguments?.append(tunnel.tunnelUUID)
        }
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                if let idx = self.managedTunnels.firstIndex(where: { $0.id == tunnel.id }) {
                    self.managedTunnels[idx].status = proc.terminationStatus == 0 ? .stopped : .error
                    self.managedTunnels[idx].pid = nil
                }
                self.managedProcesses.removeValue(forKey: tunnel.id)
                HistoryService.shared.log(.info, .tunnel, "Tunnel '\(tunnel.name)' stopped (exit: \(proc.terminationStatus))")
            }
        }
        
        do {
            try process.run()
            managedProcesses[tunnel.id] = process
            managedTunnels[index].status = .running
            managedTunnels[index].pid = process.processIdentifier
            managedTunnels[index].lastStarted = Date()
            HistoryService.shared.log(.info, .tunnel, "Tunnel '\(tunnel.name)' started (PID: \(process.processIdentifier))")
            NotificationHelper.send(title: "Tünel Başlatıldı", body: "'\(tunnel.displayName)' başarıyla başlatıldı.", category: .tunnelStarted)
            
            // Read output in background
            readProcessOutput(outputPipe, tunnelName: tunnel.name)
        } catch {
            managedTunnels[index].status = .error
            HistoryService.shared.log(.error, .tunnel, "Failed to start '\(tunnel.name)': \(error.localizedDescription)")
            NotificationHelper.send(title: "Tünel Hatası", body: "'\(tunnel.displayName)' başlatılamadı: \(error.localizedDescription)", category: .error)
        }
    }
    
    func stopTunnel(_ tunnel: ManagedTunnel) async {
        guard let index = managedTunnels.firstIndex(where: { $0.id == tunnel.id }) else { return }
        managedTunnels[index].status = .stopping
        
        if let process = managedProcesses[tunnel.id] {
            process.terminate()
            managedProcesses.removeValue(forKey: tunnel.id)
        } else if let pid = tunnel.pid {
            kill(pid, SIGTERM)
        }
        
        managedTunnels[index].status = .stopped
        managedTunnels[index].pid = nil
        HistoryService.shared.log(.info, .tunnel, "Tunnel '\(tunnel.name)' stopped")
        NotificationHelper.send(title: "Tünel Durduruldu", body: "'\(tunnel.displayName)' durduruldu.", category: .tunnelStopped)
    }
    
    func startAllTunnels() async {
        for tunnel in managedTunnels where tunnel.status == .stopped {
            await startTunnel(tunnel)
        }
    }
    
    func stopAllTunnels() async {
        for tunnel in managedTunnels where tunnel.status == .running {
            await stopTunnel(tunnel)
        }
    }
    
    func deleteTunnel(_ tunnel: ManagedTunnel) async {
        await stopTunnel(tunnel)
        
        // Delete config file
        try? FileManager.default.removeItem(atPath: tunnel.configPath)
        
        // Run cloudflared tunnel delete
        if !tunnel.tunnelUUID.isEmpty {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cloudflaredPath)
            process.arguments = ["tunnel", "delete", tunnel.tunnelUUID]
            try? process.run()
            process.waitUntilExit()
        }
        
        managedTunnels.removeAll { $0.id == tunnel.id }
        HistoryService.shared.log(.warning, .tunnel, "Tunnel '\(tunnel.name)' deleted")
    }
    
    // MARK: - Create Tunnel
    func createTunnel(name: String, hostname: String, port: Int, protocol tunnelProtocol: TunnelProtocol,
                      source: ManagedTunnel.TunnelSource = .manual) async throws -> ManagedTunnel {
        guard cloudflaredInstalled else {
            throw NSError(domain: "CloudTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: "cloudflared not installed"])
        }
        
        // Create tunnel via cloudflared
        let createProcess = Process()
        createProcess.executableURL = URL(fileURLWithPath: cloudflaredPath)
        createProcess.arguments = ["tunnel", "create", name]
        let createPipe = Pipe()
        createProcess.standardOutput = createPipe
        createProcess.standardError = createPipe
        
        try createProcess.run()
        createProcess.waitUntilExit()
        
        let createOutput = String(data: (try? createPipe.fileHandleForReading.readDataToEndOfFile()) ?? Data(), encoding: .utf8) ?? ""
        
        // Extract UUID from output
        var tunnelUUID = ""
        if let range = createOutput.range(of: #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#, options: .regularExpression) {
            tunnelUUID = String(createOutput[range])
        }
        
        guard createProcess.terminationStatus == 0 else {
            throw NSError(domain: "CloudTunnel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create tunnel: \(createOutput)"])
        }
        
        // Generate config file
        let configDir = (configDirectory as NSString).expandingTildeInPath
        let configPath = "\(configDir)/\(name).yml"
        
        let protocolScheme = tunnelProtocol == .https ? "https" : "http"
        let configContent = """
tunnel: \(tunnelUUID)
credentials-file: \(configDir)/\(tunnelUUID).json

ingress:
  - hostname: \(hostname)
    service: \(protocolScheme)://localhost:\(port)
  - service: http_status:404
"""
        
        try configContent.write(toFile: configPath, atomically: true, encoding: .utf8)
        
        // Route DNS if hostname is provided
        if !hostname.isEmpty {
            try await routeDNS(tunnelID: tunnelUUID, hostname: hostname)
        }
        
        let tunnel = ManagedTunnel(
            name: name, configPath: configPath, hostname: hostname,
            port: port, tunnelProtocol: tunnelProtocol,
            tunnelUUID: tunnelUUID, source: source
        )
        
        managedTunnels.append(tunnel)
        HistoryService.shared.log(.info, .tunnel, "Created tunnel '\(name)' → \(hostname)")
        
        return tunnel
    }
    
    // MARK: - DNS Routing
    
    /// Route DNS for a tunnel: `cloudflared tunnel route dns <tunnelID> <hostname>`
    func routeDNS(tunnelID: String, hostname: String) async throws {
        guard cloudflaredInstalled else {
            throw NSError(domain: "CloudTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: "cloudflared not installed"])
        }
        guard !tunnelID.isEmpty else {
            throw NSError(domain: "CloudTunnel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Tunnel UUID is empty"])
        }
        guard !hostname.isEmpty else {
            throw NSError(domain: "CloudTunnel", code: 4, userInfo: [NSLocalizedDescriptionKey: "Hostname is empty"])
        }
        guard isLoggedIn else {
            throw NSError(domain: "CloudTunnel", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cloudflare login required. Go to Settings → Advanced → Login first."])
        }
        
        let output = try await runCloudflared(["tunnel", "route", "dns", "--overwrite-dns", tunnelID, hostname])
        
        if output.lowercased().contains("failed") || output.lowercased().contains("error") {
            throw NSError(domain: "CloudTunnel", code: 6, userInfo: [NSLocalizedDescriptionKey: "DNS routing failed: \(output)"])
        }
        
        HistoryService.shared.log(.info, .tunnel, "DNS route: \(hostname) → tunnel \(tunnelID)")
    }
    
    /// Update DNS routing for an existing managed tunnel
    func updateTunnelDNS(_ tunnel: ManagedTunnel, hostname: String) async throws {
        guard !tunnel.tunnelUUID.isEmpty else {
            throw NSError(domain: "CloudTunnel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Tunnel has no UUID — cannot route DNS"])
        }
        
        try await routeDNS(tunnelID: tunnel.tunnelUUID, hostname: hostname)
        
        // Update config file with new hostname
        if let index = managedTunnels.firstIndex(where: { $0.id == tunnel.id }) {
            managedTunnels[index].hostname = hostname
            
            // Rewrite the config file
            if FileManager.default.fileExists(atPath: tunnel.configPath),
               var content = try? String(contentsOfFile: tunnel.configPath, encoding: .utf8) {
                // Replace hostname in config
                let hostnamePattern = #"(?m)^(\s*-?\s*hostname:\s*).*$"#
                if let range = content.range(of: hostnamePattern, options: .regularExpression) {
                    let indent = content[range].prefix(while: { $0 == " " || $0 == "-" || $0 == "\t" })
                    content.replaceSubrange(range, with: "\(indent)hostname: \(hostname)")
                    try? content.write(toFile: tunnel.configPath, atomically: true, encoding: .utf8)
                }
            }
        }
    }
    
    /// List current DNS routes for a tunnel
    func listTunnelDNSRoutes(tunnelID: String) async -> [String] {
        guard cloudflaredInstalled, !tunnelID.isEmpty else { return [] }
        
        let output = (try? await runCloudflared(["tunnel", "route", "dns", tunnelID])) ?? ""
        // Parse routes from output
        var routes: [String] = []
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("ID") && !trimmed.hasPrefix("-") {
                routes.append(trimmed)
            }
        }
        return routes
    }
    
    /// Helper to run cloudflared and capture output
    private func runCloudflared(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cloudflaredPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                let data = (try? pipe.fileHandleForReading.readDataToEndOfFile()) ?? Data()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
        }
    }
    
    // MARK: - Quick Tunnels
    func startQuickTunnel(localURL: String, preset: QuickTunnelPreset? = nil) async -> QuickTunnel? {
        guard cloudflaredInstalled else {
            HistoryService.shared.log(.error, .tunnel, "cloudflared not installed")
            return nil
        }
        
        var tunnel = QuickTunnel(
            localURL: localURL,
            publicURL: nil,
            status: .starting,
            process: nil,
            pid: nil,
            startedAt: Date(),
            preset: preset
        )
        
        quickTunnels.append(tunnel)
        guard let index = quickTunnels.firstIndex(where: { $0.id == tunnel.id }) else { return nil }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cloudflaredPath)
        process.arguments = ["tunnel", "--url", localURL]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.quickTunnels.removeAll { $0.id == tunnel.id }
            }
        }
        
        do {
            try process.run()
            tunnel.process = process
            tunnel.pid = process.processIdentifier
            quickTunnels[index].process = process
            quickTunnels[index].pid = process.processIdentifier
            
            // Parse public URL from output
            Task.detached {
                let handle = outputPipe.fileHandleForReading
                while true {
                    guard let data = try? handle.availableData, !data.isEmpty else { break }
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if let urlRange = output.range(of: #"https://[a-zA-Z0-9-]+\.trycloudflare\.com"#, options: .regularExpression) {
                        let publicURL = String(output[urlRange])
                        await MainActor.run {
                            if let idx = self.quickTunnels.firstIndex(where: { $0.id == tunnel.id }) {
                                self.quickTunnels[idx].publicURL = publicURL
                                self.quickTunnels[idx].status = .running
                            }
                        }
                        HistoryService.shared.logFromBackground(.info, .tunnel, "Quick tunnel active: \(publicURL)")
                        break
                    }
                }
            }
            
            HistoryService.shared.log(.info, .tunnel, "Quick tunnel starting for \(localURL)")
            return tunnel
        } catch {
            quickTunnels.removeAll { $0.id == tunnel.id }
            HistoryService.shared.log(.error, .tunnel, "Quick tunnel failed: \(error)")
            return nil
        }
    }
    
    func stopQuickTunnel(_ tunnel: QuickTunnel) {
        tunnel.process?.terminate()
        quickTunnels.removeAll { $0.id == tunnel.id }
        HistoryService.shared.log(.info, .tunnel, "Quick tunnel stopped: \(tunnel.localURL)")
    }
    
    func stopAllQuickTunnels() {
        for tunnel in quickTunnels {
            tunnel.process?.terminate()
        }
        quickTunnels.removeAll()
    }
    
    // MARK: - Status Monitor
    private func startStatusMonitor() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkProcessStatus()
            }
        }
    }
    
    /// Call this when checkInterval changes to restart the timer
    func restartStatusMonitor() {
        startStatusMonitor()
    }
    
    private func checkProcessStatus() {
        for i in managedTunnels.indices {
            if managedTunnels[i].status == .running {
                if let pid = managedTunnels[i].pid {
                    if kill(pid, 0) != 0 {
                        managedTunnels[i].status = .stopped
                        managedTunnels[i].pid = nil
                        managedProcesses.removeValue(forKey: managedTunnels[i].id)
                    }
                }
            }
        }
    }
    
    // MARK: - Directory Monitor
    private func startDirectoryMonitor() {
        let path = (configDirectory as NSString).expandingTildeInPath
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        
        dirMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        
        dirMonitor?.setEventHandler { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.scanConfigFiles()
            }
        }
        
        dirMonitor?.setCancelHandler { close(fd) }
        dirMonitor?.resume()
    }
    
    // MARK: - Helpers
    private func readProcessOutput(_ pipe: Pipe, tunnelName: String) {
        Task.detached {
            let handle = pipe.fileHandleForReading
            while true {
                guard let data = try? handle.availableData, !data.isEmpty else { break }
                let output = String(data: data, encoding: .utf8) ?? ""
                for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                    let level: LogEntry.LogLevel = line.lowercased().contains("err") ? .error : .debug
                    HistoryService.shared.logFromBackground(level, .tunnel, "[\(tunnelName)] \(line)")
                }
            }
        }
    }
    
    // MARK: - Stats
    var runningManagedCount: Int { managedTunnels.filter { $0.status == .running }.count }
    var runningQuickCount: Int { quickTunnels.filter { $0.status == .running }.count }
    var totalRunning: Int { runningManagedCount + runningQuickCount }
    var errorCount: Int { managedTunnels.filter { $0.status == .error }.count }
    
    deinit {
        statusTimer?.invalidate()
        dirMonitor?.cancel()
    }
}
