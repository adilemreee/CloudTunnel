// MARK: - MAMP Service
// Detects MAMP sites and manages Apache/MySQL

import Foundation
import SwiftUI
import Combine

@MainActor
final class MAMPService: ObservableObject {
    static let shared = MAMPService()
    
    @Published var sites: [MAMPSite] = []
    @Published var isMAMPInstalled = false
    @Published var isMAMPRunning = false
    @Published var isLoading = false
    @Published var isStarting = false
    @Published var isStopping = false
    @Published var lastStatusMessage: String?
    @Published var statusMessageType: StatusMessageType = .info
    
    enum StatusMessageType { case success, error, info }
    
    @AppStorage("mampBasePath") var mampBasePath = "/Applications/MAMP"
    @AppStorage("mampSitesDir") var mampSitesDir = "/Applications/MAMP/htdocs"
    @AppStorage("mampApacheConfig") var mampApacheConfig = "/Applications/MAMP/conf/apache"
    @AppStorage("mampVHostConfig") var mampVHostConfig = "/Applications/MAMP/conf/apache/extra/httpd-vhosts.conf"
    @AppStorage("mampHttpdConf") var mampHttpdConf = "/Applications/MAMP/conf/apache/httpd.conf"
    @AppStorage("autoStartMAMP") var autoStartMAMP = false
    
    private init() {
        detectMAMP()
        if autoStartMAMP {
            Task { await startMAMP() }
        }
    }
    
    // MARK: - Detection
    func detectMAMP() {
        isMAMPInstalled = FileManager.default.fileExists(atPath: mampBasePath)
        if isMAMPInstalled {
            checkMAMPStatus()
            scanSites()
        }
    }
    
    func checkMAMPStatus() {
        let basePath = mampBasePath
        Task.detached {
            let running = await self.checkMAMPStatusSync(basePath)
            await MainActor.run {
                self.isMAMPRunning = running
            }
        }
    }
    
    // MARK: - Site Scanning
    func scanSites() {
        isLoading = true
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: mampSitesDir),
              let contents = try? fm.contentsOfDirectory(atPath: mampSitesDir) else {
            isLoading = false
            return
        }
        
        // Parse VHost config to build a map: documentRoot -> [VHostEntry]
        let vhostMap = parseVHostConfig()
        
        var foundSites: [MAMPSite] = []
        
        for item in contents {
            let itemPath = (mampSitesDir as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                // Skip hidden directories  
                guard !item.hasPrefix(".") else { continue }
                var site = MAMPSite(name: item, path: itemPath)
                
                // Match VHost entries by DocumentRoot
                if let entries = vhostMap[itemPath] {
                    site.vhosts = entries
                    // Use the first VHost's port as the default
                    if let firstPort = entries.first?.port {
                        site.port = firstPort
                    }
                }
                
                foundSites.append(site)
            }
        }
        
        sites = foundSites.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false
        HistoryService.shared.log(.info, .mamp, "Found \(sites.count) MAMP sites")
    }
    
    /// Parse httpd-vhosts.conf and return a map of documentRoot -> [VHostEntry]
    private func parseVHostConfig() -> [String: [MAMPSite.VHostEntry]] {
        guard let content = try? String(contentsOfFile: mampVHostConfig, encoding: .utf8) else {
            return [:]
        }
        
        var result: [String: [MAMPSite.VHostEntry]] = [:]
        
        // Match each <VirtualHost *:PORT> ... </VirtualHost> block
        let blockPattern = #"<VirtualHost\s+\*:(\d+)>([\s\S]*?)</VirtualHost>"#
        guard let blockRegex = try? NSRegularExpression(pattern: blockPattern, options: []) else { return [:] }
        
        let nsContent = content as NSString
        let matches = blockRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            
            let portStr = nsContent.substring(with: match.range(at: 1))
            let blockBody = nsContent.substring(with: match.range(at: 2))
            let port = Int(portStr) ?? 8888
            
            // Extract ServerName
            var serverName = ""
            if let snRegex = try? NSRegularExpression(pattern: #"(?m)^\s*ServerName\s+(\S+)"#),
               let snMatch = snRegex.firstMatch(in: blockBody, range: NSRange(location: 0, length: (blockBody as NSString).length)),
               snMatch.numberOfRanges >= 2 {
                serverName = (blockBody as NSString).substring(with: snMatch.range(at: 1))
            }
            
            // Extract DocumentRoot
            var docRoot = ""
            if let drRegex = try? NSRegularExpression(pattern: #"(?m)^\s*DocumentRoot\s+"?([^"\n]+)"?"#),
               let drMatch = drRegex.firstMatch(in: blockBody, range: NSRange(location: 0, length: (blockBody as NSString).length)),
               drMatch.numberOfRanges >= 2 {
                docRoot = (blockBody as NSString).substring(with: drMatch.range(at: 1))
                    .trimmingCharacters(in: .whitespaces)
            }
            
            guard !docRoot.isEmpty else { continue }
            
            let entry = MAMPSite.VHostEntry(serverName: serverName, port: port, documentRoot: docRoot)
            result[docRoot, default: []].append(entry)
        }
        
        return result
    }
    
    // MARK: - Start/Stop MAMP
    func startMAMP() async {
        isStarting = true
        lastStatusMessage = nil
        
        let basePath = mampBasePath
        
        // Run start process off the main thread
        let startError: String? = await Task.detached {
            let fm = FileManager.default
            
            // Method 1: Run start.sh via /bin/sh (MAMP's shebang is broken: '# /bin/sh' instead of '#!/bin/sh')
            let startScript = "\(basePath)/bin/start.sh"
            if fm.fileExists(atPath: startScript) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = [startScript]
                process.standardOutput = Pipe()
                let errPipe = Pipe()
                process.standardError = errPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        return nil as String?
                    }
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    return String(data: errData, encoding: .utf8) ?? "start.sh failed"
                } catch {
                    // Fall through to method 2
                }
            }
            
            // Method 2: Start Apache and MySQL individually
            let apachectl = "\(basePath)/Library/bin/apachectl"
            if fm.fileExists(atPath: apachectl) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: apachectl)
                p.arguments = ["start"]
                p.standardOutput = Pipe()
                p.standardError = Pipe()
                try? p.run()
                p.waitUntilExit()
            }
            
            let mysqlScript = "\(basePath)/bin/startMysql.sh"
            if fm.fileExists(atPath: mysqlScript) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/sh")
                p.arguments = [mysqlScript]
                p.standardOutput = Pipe()
                p.standardError = Pipe()
                try? p.run()
                // mysqld_safe runs in background (&), so script exits quickly
                p.waitUntilExit()
            }
            
            // Method 3: Also open MAMP app (ensures MAMP GUI is available)
            let openProcess = Process()
            openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProcess.arguments = ["-a", "MAMP"]
            openProcess.standardOutput = Pipe()
            openProcess.standardError = Pipe()
            try? openProcess.run()
            openProcess.waitUntilExit()
            
            return nil as String?
        }.value
        
        if let err = startError {
            HistoryService.shared.log(.error, .mamp, "MAMP start script error: \(err)")
        }
        
        // Poll up to 30 seconds for the servers to actually start
        var started = false
        for attempt in 1...10 {
            try? await Task.sleep(for: .seconds(3))
            let status = await checkMAMPStatusSync(basePath)
            if status {
                started = true
                break
            }
            if attempt <= 3 {
                HistoryService.shared.log(.debug, .mamp, "Waiting for MAMP to start... attempt \(attempt)/10")
            }
        }
        
        isMAMPRunning = started
        isStarting = false
        
        if started {
            lastStatusMessage = "MAMP başarıyla başlatıldı"
            statusMessageType = .success
            scanSites()
            HistoryService.shared.log(.info, .mamp, "MAMP started successfully")
        } else {
            lastStatusMessage = "MAMP başlatılamadı. Lütfen MAMP uygulamasını manuel olarak başlatın."
            statusMessageType = .error
            HistoryService.shared.log(.error, .mamp, "MAMP failed to start after 21 seconds")
        }
        
        // Auto-dismiss message after 6 seconds
        Task {
            try? await Task.sleep(for: .seconds(6))
            lastStatusMessage = nil
        }
    }
    
    func stopMAMP() async {
        isStopping = true
        lastStatusMessage = nil
        
        let basePath = mampBasePath
        
        await Task.detached {
            let fm = FileManager.default
            
            // Method 1: Run stop.sh via /bin/sh (broken shebang workaround)
            let stopScript = "\(basePath)/bin/stop.sh"
            if fm.fileExists(atPath: stopScript) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = [stopScript]
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                try? process.run()
                process.waitUntilExit()
            }
            
            // Method 2 (fallback): Stop Apache and MySQL directly + kill stray processes
            let apachectl = "\(basePath)/Library/bin/apachectl"
            if fm.fileExists(atPath: apachectl) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: apachectl)
                p.arguments = ["stop"]
                p.standardOutput = Pipe()
                p.standardError = Pipe()
                try? p.run()
                p.waitUntilExit()
            }
            
            // Kill any remaining MAMP-related processes
            for pattern in ["MAMP.*httpd", "MAMP.*mysqld", "MAMP.*mysqld_safe", "MAMP.*apache"] {
                let kill = Process()
                kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                kill.arguments = ["-f", pattern]
                kill.standardOutput = Pipe()
                kill.standardError = Pipe()
                try? kill.run()
                kill.waitUntilExit()
            }
            
            // Quit the MAMP app
            let quitApp = Process()
            quitApp.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            quitApp.arguments = ["-e", "tell application \"MAMP\" to quit"]
            quitApp.standardOutput = Pipe()
            quitApp.standardError = Pipe()
            try? quitApp.run()
            quitApp.waitUntilExit()
        }.value
        
        // Poll to confirm stop
        var stopped = false
        for _ in 1...5 {
            try? await Task.sleep(for: .seconds(2))
            let status = await checkMAMPStatusSync(basePath)
            if !status {
                stopped = true
                break
            }
        }
        
        isMAMPRunning = !stopped
        isStopping = false
        
        if stopped {
            lastStatusMessage = "MAMP başarıyla durduruldu"
            statusMessageType = .success
            HistoryService.shared.log(.info, .mamp, "MAMP stopped successfully")
        } else {
            lastStatusMessage = "MAMP durdurulamadı. Lütfen MAMP uygulamasını kontrol edin."
            statusMessageType = .error
            HistoryService.shared.log(.error, .mamp, "MAMP failed to stop")
        }
        
        Task {
            try? await Task.sleep(for: .seconds(6))
            lastStatusMessage = nil
        }
    }
    
    /// Check if MAMP servers are running by looking for processes and checking pid files
    nonisolated private func checkMAMPStatusSync(_ basePath: String = "/Applications/MAMP") async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            // Comprehensive check: any process with /Applications/MAMP in path,
            // OR MySQL pid file exists and process is alive,
            // OR httpd is running with MAMP config
            process.arguments = ["-c", """
                pgrep -f '/Applications/MAMP' > /dev/null 2>&1 || \\
                ([ -f \"\(basePath)/tmp/mysql/mysql.pid\" ] && kill -0 $(cat \"\(basePath)/tmp/mysql/mysql.pid\" 2>/dev/null) 2>/dev/null) || \\
                curl -s --connect-timeout 2 http://localhost:8888 > /dev/null 2>&1
                """]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
            continuation.resume(returning: process.terminationStatus == 0)
        }
    }
    
    // MARK: - VHost Configuration
    func addVHost(hostname: String, sitePath: String, port: Int = 8888) throws {
        guard FileManager.default.fileExists(atPath: mampVHostConfig) else {
            throw NSError(domain: "MAMP", code: 1, userInfo: [NSLocalizedDescriptionKey: "VHost config not found at \(mampVHostConfig)"])
        }
        
        // Read existing content to check for duplicates
        guard let existingContent = try? String(contentsOfFile: mampVHostConfig, encoding: .utf8) else {
            throw NSError(domain: "MAMP", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot read VHost config file"])
        }
        
        // Check for duplicate ServerName
        let serverNamePattern = #"(?mi)^\s*ServerName\s+"# + NSRegularExpression.escapedPattern(for: hostname) + #"\s*$"#
        if existingContent.range(of: serverNamePattern, options: .regularExpression) != nil {
            HistoryService.shared.log(.warning, .mamp, "VHost for \(hostname) already exists, skipping")
            throw NSError(domain: "MAMP", code: 3, userInfo: [NSLocalizedDescriptionKey: "VHost for '\(hostname)' already exists in the configuration file."])
        }
        
        // Add NameVirtualHost directive if not present
        if !existingContent.contains("NameVirtualHost *:\(port)") {
            let nameVHostDirective = "\nNameVirtualHost *:\(port)\n"
            var updatedContent = existingContent
            updatedContent = nameVHostDirective + updatedContent
            try updatedContent.write(toFile: mampVHostConfig, atomically: true, encoding: .utf8)
        }
        
        let vhostEntry = """
        
        # CloudTunnel Auto-Generated VHost for \(hostname)
        <VirtualHost *:\(port)>
            ServerName \(hostname)
            DocumentRoot "\(sitePath)"
            <Directory "\(sitePath)">
                Options Indexes FollowSymLinks
                AllowOverride All
                Require all granted
            </Directory>
            ErrorLog "/Applications/MAMP/logs/\(hostname)-error.log"
            CustomLog "/Applications/MAMP/logs/\(hostname)-access.log" common
        </VirtualHost>
        """
        
        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: mampVHostConfig))
        fileHandle.seekToEndOfFile()
        fileHandle.write(vhostEntry.data(using: .utf8)!)
        fileHandle.closeFile()
        
        // Also update httpd.conf to add Listen directive if needed
        try addListenDirective(port: port)
        
        HistoryService.shared.log(.info, .mamp, "Added VHost for \(hostname)")
    }
    
    /// Ensure httpd.conf has a Listen directive for the given port
    private func addListenDirective(port: Int) throws {
        guard FileManager.default.fileExists(atPath: mampHttpdConf),
              var content = try? String(contentsOfFile: mampHttpdConf, encoding: .utf8) else { return }
        
        let listenPattern = #"(?m)^Listen\s+\#(port)\s*$"#
        if content.range(of: listenPattern, options: .regularExpression) != nil {
            return // Already has this Listen directive
        }
        
        // Find the last existing Listen directive and add after it
        let lines = content.components(separatedBy: "\n")
        var lastListenIndex: Int?
        for (index, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("Listen ") {
                lastListenIndex = index
            }
        }
        
        if let insertIndex = lastListenIndex {
            var mutableLines = lines
            mutableLines.insert("Listen \(port)", at: insertIndex + 1)
            content = mutableLines.joined(separator: "\n")
            try content.write(toFile: mampHttpdConf, atomically: true, encoding: .utf8)
            HistoryService.shared.log(.info, .mamp, "Added Listen \(port) to httpd.conf")
        }
    }
    
    /// Remove a VHost entry for a given hostname
    func removeVHost(hostname: String) throws {
        guard FileManager.default.fileExists(atPath: mampVHostConfig),
              var content = try? String(contentsOfFile: mampVHostConfig, encoding: .utf8) else { return }
        
        // Match the entire VHost block including the comment
        let pattern = #"\n\s*# CloudTunnel Auto-Generated VHost for "# +
            NSRegularExpression.escapedPattern(for: hostname) +
            #"[\s\S]*?</VirtualHost>"#
        
        if let range = content.range(of: pattern, options: .regularExpression) {
            content.removeSubrange(range)
            try content.write(toFile: mampVHostConfig, atomically: true, encoding: .utf8)
            HistoryService.shared.log(.info, .mamp, "Removed VHost for \(hostname)")
        }
    }
    
    // MARK: - Fix MySQL Socket
    func fixMySQLSocket() async {
        let appleScript = """
        do shell script "ln -sf /Applications/MAMP/tmp/mysql/mysql.sock /tmp/mysql.sock && ln -sf /Applications/MAMP/tmp/mysql/mysql.sock /var/mysql/mysql.sock" with administrator privileges
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        try? process.run()
        process.waitUntilExit()
        
        HistoryService.shared.log(.info, .mamp, "MySQL socket fix applied")
    }
    
    // MARK: - Fix phpMyAdmin
    func fixPhpMyAdmin() {
        let configPath = "\(mampBasePath)/bin/phpMyAdmin/config.inc.php"
        guard FileManager.default.fileExists(atPath: configPath),
              var content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }
        
        content = content.replacingOccurrences(of: "'localhost'", with: "'127.0.0.1'")
        try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
        
        HistoryService.shared.log(.info, .mamp, "phpMyAdmin config fixed")
    }
}
