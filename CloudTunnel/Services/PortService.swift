// MARK: - Port Service
// Checks port availability and finds free ports

import Foundation

@MainActor
final class PortService: ObservableObject {
    static let shared = PortService()
    
    private init() {}
    
    // MARK: - Check Port
    nonisolated func isPortAvailable(_ port: Int) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return false }
        defer { close(socketFD) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    // MARK: - Find Free Port
    nonisolated func findFreePort(startingFrom start: Int = 50000) -> Int? {
        for port in start..<(start + 1000) {
            if isPortAvailable(port) { return port }
        }
        return nil
    }
    
    // MARK: - Get Process on Port
    nonisolated func processOnPort(_ port: Int) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-ti", ":\(port)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try? process.run()
        process.waitUntilExit()
        
        guard let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
              let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return nil }
        
        return output
    }
}
