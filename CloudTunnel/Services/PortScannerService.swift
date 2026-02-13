// MARK: - Port Scanner Service
// Scans local ports to discover running services and provides quick tunnel creation

import Foundation
import SwiftUI
import Combine

@MainActor
final class PortScannerService: ObservableObject {
    static let shared = PortScannerService()
    
    // MARK: - Published State
    @Published var discoveredPorts: [DiscoveredPort] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var lastScanDate: Date?
    
    private init() {}
    
    // MARK: - Discovered Port
    struct DiscoveredPort: Identifiable, Equatable {
        let id = UUID()
        let port: Int
        let processName: String
        let pid: Int32
        let user: String
        let type: PortType
        let command: String
        
        var suggestedProtocol: TunnelProtocol {
            switch port {
            case 443:           return .https
            case 22:            return .ssh
            case 3389:          return .rdp
            case 80, 8080, 8888, 3000, 3001, 5000, 5173, 4200, 8000, 8001:
                return .http
            default:            return .http
            }
        }
        
        var serviceName: String {
            // Known service detection
            let lowerCmd = command.lowercased()
            let lowerProc = processName.lowercased()
            
            if lowerProc.contains("node") || lowerCmd.contains("node") {
                if lowerCmd.contains("next") { return "Next.js" }
                if lowerCmd.contains("nuxt") { return "Nuxt" }
                if lowerCmd.contains("vite") { return "Vite (React/Vue/Svelte)" }
                if lowerCmd.contains("angular") || lowerCmd.contains("ng") { return "Angular" }
                if lowerCmd.contains("express") { return "Express" }
                return "Node.js"
            }
            if lowerProc.contains("python") || lowerCmd.contains("python") {
                if lowerCmd.contains("django") { return "Django" }
                if lowerCmd.contains("flask") { return "Flask" }
                if lowerCmd.contains("uvicorn") || lowerCmd.contains("fastapi") { return "FastAPI" }
                return "Python"
            }
            if lowerProc.contains("ruby") || lowerCmd.contains("rails") { return "Ruby on Rails" }
            if lowerProc.contains("php") || lowerCmd.contains("php") { return "PHP" }
            if lowerProc.contains("java") || lowerCmd.contains("java") {
                if lowerCmd.contains("spring") { return "Spring Boot" }
                return "Java"
            }
            if lowerProc.contains("go") || lowerCmd.contains("go") { return "Go" }
            if lowerProc.contains("rust") || lowerCmd.contains("cargo") { return "Rust" }
            if lowerProc.contains("nginx") { return "Nginx" }
            if lowerProc.contains("httpd") || lowerProc.contains("apache") { return "Apache" }
            if lowerProc.contains("postgres") { return "PostgreSQL" }
            if lowerProc.contains("mysql") { return "MySQL" }
            if lowerProc.contains("redis") { return "Redis" }
            if lowerProc.contains("mongo") { return "MongoDB" }
            if lowerProc.contains("docker") { return "Docker" }
            
            return processName
        }
        
        var serviceIcon: String {
            let name = serviceName.lowercased()
            if name.contains("node") || name.contains("next") || name.contains("nuxt") ||
               name.contains("express") || name.contains("vite") || name.contains("angular") {
                return "j.square"
            }
            if name.contains("python") || name.contains("django") || name.contains("flask") || name.contains("fastapi") {
                return "p.square"
            }
            if name.contains("ruby") { return "r.square" }
            if name.contains("php") { return "p.circle" }
            if name.contains("java") || name.contains("spring") { return "cup.and.saucer" }
            if name.contains("go") { return "g.square" }
            if name.contains("nginx") || name.contains("apache") { return "server.rack" }
            if name.contains("postgres") || name.contains("mysql") || name.contains("redis") || name.contains("mongo") {
                return "cylinder"
            }
            if name.contains("docker") { return "shippingbox" }
            return "network"
        }
        
        var serviceColor: Color {
            let name = serviceName.lowercased()
            if name.contains("next") { return .primary }
            if name.contains("vite") || name.contains("react") { return Color(hex: "61DAFB") }
            if name.contains("vue") || name.contains("nuxt") { return Color(hex: "42B883") }
            if name.contains("angular") { return Color(hex: "DD0031") }
            if name.contains("django") || name.contains("python") { return Color(hex: "3776AB") }
            if name.contains("flask") { return .primary }
            if name.contains("express") || name.contains("node") { return Color(hex: "68A063") }
            if name.contains("spring") { return Color(hex: "6DB33F") }
            if name.contains("ruby") || name.contains("rails") { return Color(hex: "CC0000") }
            if name.contains("php") || name.contains("laravel") { return Color(hex: "777BB4") }
            if name.contains("go") { return Color(hex: "00ADD8") }
            if name.contains("postgres") { return Color(hex: "336791") }
            if name.contains("mysql") { return Color(hex: "4479A1") }
            if name.contains("redis") { return Color(hex: "DC382D") }
            if name.contains("mongo") { return Color(hex: "47A248") }
            return CTColors.brand
        }
    }
    
    enum PortType: String {
        case tcp = "TCP"
        case udp = "UDP"
    }
    
    // MARK: - Scan
    func scanPorts() async {
        isScanning = true
        scanProgress = 0
        discoveredPorts = []
        
        let results = await withCheckedContinuation { (continuation: CheckedContinuation<[DiscoveredPort], Never>) in
            Task.detached {
                let ports = self.performLsofScan()
                continuation.resume(returning: ports)
            }
        }
        
        discoveredPorts = results.sorted { $0.port < $1.port }
        isScanning = false
        scanProgress = 1.0
        lastScanDate = Date()
    }
    
    // MARK: - lsof Scan
    nonisolated private func performLsofScan() -> [DiscoveredPort] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        
        guard let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
              let output = String(data: data, encoding: .utf8) else {
            return []
        }
        
        var seenPorts = Set<Int>()
        var results: [DiscoveredPort] = []
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines.dropFirst() { // Skip header
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 9 else { continue }
            
            let processName = components[0]
            let pidStr = components[1]
            let user = components[2]
            let nameField = components.last ?? ""
            
            // Skip system processes
            let lowerProc = processName.lowercased()
            if lowerProc == "launchd" || lowerProc == "systemuiserv" || lowerProc == "rapportd" ||
               lowerProc == "controlce" || lowerProc == "airplayd" {
                continue
            }
            
            // Parse port from name field (e.g., "*:3000" or "127.0.0.1:8080")
            guard let colonIndex = nameField.lastIndex(of: ":"),
                  let port = Int(nameField[nameField.index(after: colonIndex)...]),
                  port > 0 && port < 65536 else {
                continue
            }
            
            // Skip duplicates
            guard !seenPorts.contains(port) else { continue }
            seenPorts.insert(port)
            
            let pid = Int32(pidStr) ?? 0
            
            // Get full command
            let command = getProcessCommand(pid: pid)
            
            results.append(DiscoveredPort(
                port: port,
                processName: processName,
                pid: pid,
                user: user,
                type: .tcp,
                command: command
            ))
        }
        
        return results
    }
    
    nonisolated private func getProcessCommand(pid: Int32) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "command="]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        
        guard let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
              let output = String(data: data, encoding: .utf8) else {
            return ""
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
