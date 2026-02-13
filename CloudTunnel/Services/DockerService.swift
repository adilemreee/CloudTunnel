// MARK: - Docker Service
// Detects and manages Docker containers for tunnel creation

import Foundation
import Combine

@MainActor
final class DockerService: ObservableObject {
    static let shared = DockerService()
    
    @Published var containers: [DockerContainer] = []
    @Published var isDockerInstalled = false
    @Published var isDockerRunning = false
    @Published var isLoading = false
    @Published var dockerVersion: String?
    
    private var dockerPath: String?
    private var refreshTimer: Timer?
    
    private init() {
        detectDocker()
    }
    
    // MARK: - Docker Detection
    func detectDocker() {
        let searchPaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker"
        ]
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                dockerPath = path
                isDockerInstalled = true
                checkDockerStatus()
                return
            }
        }
        
        isDockerInstalled = false
        HistoryService.shared.log(.info, .docker, "Docker not found on system")
    }
    
    // MARK: - Status Check
    func checkDockerStatus() {
        guard let dockerPath else { return }
        
        Task.detached { [dockerPath] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: dockerPath)
            process.arguments = ["info", "--format", "{{.ServerVersion}}"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            try? process.run()
            process.waitUntilExit()
            
            let data = try? pipe.fileHandleForReading.readDataToEndOfFile()
            let version = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            await MainActor.run {
                self.isDockerRunning = process.terminationStatus == 0
                self.dockerVersion = version
                if self.isDockerRunning {
                    self.refreshContainers()
                }
            }
        }
    }
    
    // MARK: - Container List
    func refreshContainers() {
        guard let dockerPath, isDockerRunning else { return }
        isLoading = true
        
        Task.detached { [dockerPath] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: dockerPath)
            process.arguments = ["ps", "-a", "--format", "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            try? process.run()
            process.waitUntilExit()
            
            guard let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
                  let output = String(data: data, encoding: .utf8) else {
                await MainActor.run { self.isLoading = false }
                return
            }
            
            var containers: [DockerContainer] = []
            
            for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 4 else { continue }
                
                let ports = parts.count > 4 ? self.parsePorts(parts[4]) : []
                
                containers.append(DockerContainer(
                    id: parts[0],
                    name: parts[1],
                    image: parts[2],
                    status: parts[3],
                    ports: ports
                ))
            }
            
            await MainActor.run {
                self.containers = containers
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Port Parsing
    nonisolated private func parsePorts(_ portString: String) -> [DockerContainer.PortMapping] {
        var mappings: [DockerContainer.PortMapping] = []
        let pattern = #"(\d+)->(\d+)/(\w+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = portString as NSString
        let results = regex.matches(in: portString, range: NSRange(location: 0, length: nsString.length))
        
        for result in results {
            if result.numberOfRanges >= 4,
               let hostPort = Int(nsString.substring(with: result.range(at: 1))),
               let containerPort = Int(nsString.substring(with: result.range(at: 2))) {
                let proto = nsString.substring(with: result.range(at: 3))
                mappings.append(.init(hostPort: hostPort, containerPort: containerPort, proto: proto))
            }
        }
        
        return mappings
    }
    
    // MARK: - Auto Refresh
    func startAutoRefresh(interval: TimeInterval = 10) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshContainers()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    var runningContainers: [DockerContainer] { containers.filter { $0.isRunning } }
    var stoppedContainers: [DockerContainer] { containers.filter { !$0.isRunning } }
}
