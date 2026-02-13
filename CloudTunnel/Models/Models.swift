// MARK: - CloudTunnel Data Models

import SwiftUI

// MARK: - Tunnel Status
enum TunnelStatus: String, Codable, CaseIterable {
    case running, stopped, starting, stopping, error
    
    var displayName: String {
        switch self {
        case .running:  NSLocalizedString("status.running", comment: "")
        case .stopped:  NSLocalizedString("status.stopped", comment: "")
        case .starting: NSLocalizedString("status.starting", comment: "")
        case .stopping: NSLocalizedString("status.stopping", comment: "")
        case .error:    NSLocalizedString("status.error", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .running:  "checkmark.circle.fill"
        case .stopped:  "stop.circle.fill"
        case .starting: "arrow.clockwise.circle.fill"
        case .stopping: "arrow.clockwise.circle.fill"
        case .error:    "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .running:  CTColors.success
        case .stopped:  CTColors.textTertiary
        case .starting: CTColors.warning
        case .stopping: CTColors.warning
        case .error:    CTColors.danger
        }
    }
}

// MARK: - Tunnel Protocol
enum TunnelProtocol: String, Codable, CaseIterable {
    case http, https, ssh, rdp, tcp
    
    var displayName: String { rawValue.uppercased() }
    var defaultPort: Int {
        switch self {
        case .http:  80
        case .https: 443
        case .ssh:   22
        case .rdp:   3389
        case .tcp:   8080
        }
    }
    var icon: String {
        switch self {
        case .http, .https: "globe"
        case .ssh:          "terminal"
        case .rdp:          "desktopcomputer"
        case .tcp:          "network"
        }
    }
}

// MARK: - Managed Tunnel
struct ManagedTunnel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var configPath: String
    var hostname: String
    var port: Int
    var tunnelProtocol: TunnelProtocol
    var tunnelUUID: String
    var status: TunnelStatus
    var pid: Int32?
    var createdAt: Date
    var lastStarted: Date?
    var source: TunnelSource
    var isFavorite: Bool = false
    
    enum TunnelSource: String, Codable, Hashable {
        case manual, docker, mamp
        
        var icon: String {
            switch self {
            case .manual: "hand.raised"
            case .docker: "shippingbox"
            case .mamp:   "server.rack"
            }
        }
    }
    
    init(name: String, configPath: String, hostname: String = "", port: Int = 80,
         tunnelProtocol: TunnelProtocol = .http, tunnelUUID: String = "",
         source: TunnelSource = .manual) {
        self.id = UUID()
        self.name = name
        self.configPath = configPath
        self.hostname = hostname
        self.port = port
        self.tunnelProtocol = tunnelProtocol
        self.tunnelUUID = tunnelUUID
        self.status = .stopped
        self.pid = nil
        self.createdAt = Date()
        self.lastStarted = nil
        self.source = source
    }
    
    /// Human-readable display name: uses name if meaningful, otherwise hostname-derived or shortened UUID
    var displayName: String {
        let isUUID = name.range(of: #"^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$"#, options: .regularExpression) != nil
        if !isUUID && !name.isEmpty {
            return name
        }
        if !hostname.isEmpty {
            return hostname.components(separatedBy: ".").first ?? hostname
        }
        if !tunnelUUID.isEmpty {
            return String(tunnelUUID.prefix(8)) + "..."
        }
        return name
    }
}

// MARK: - Quick Tunnel
struct QuickTunnel: Identifiable {
    let id = UUID()
    var localURL: String
    var publicURL: String?
    var status: TunnelStatus
    var process: Process?
    var pid: Int32?
    var startedAt: Date
    var preset: QuickTunnelPreset?
    
    var displayName: String {
        preset?.name ?? localURL
    }
}

// MARK: - Quick Tunnel Preset
struct QuickTunnelPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let defaultPort: Int
    let color: Color
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: QuickTunnelPreset, rhs: QuickTunnelPreset) -> Bool { lhs.id == rhs.id }
    
    static let presets: [QuickTunnelPreset] = [
        .init(name: "React", icon: "atom", defaultPort: 3000, color: Color(hex: "61DAFB")),
        .init(name: "Vue", icon: "leaf", defaultPort: 5173, color: Color(hex: "42B883")),
        .init(name: "Angular", icon: "arrow.triangle.2.circlepath", defaultPort: 4200, color: Color(hex: "DD0031")),
        .init(name: "Next.js", icon: "n.square", defaultPort: 3000, color: .primary),
        .init(name: "Nuxt", icon: "n.circle", defaultPort: 3000, color: Color(hex: "00DC82")),
        .init(name: "Svelte", icon: "flame", defaultPort: 5173, color: Color(hex: "FF3E00")),
        .init(name: "Django", icon: "d.square", defaultPort: 8000, color: Color(hex: "092E20")),
        .init(name: "Flask", icon: "flask", defaultPort: 5000, color: .primary),
        .init(name: "Express", icon: "e.square", defaultPort: 3000, color: Color(hex: "68A063")),
        .init(name: "Laravel", icon: "l.square", defaultPort: 8000, color: Color(hex: "FF2D20")),
        .init(name: "Spring Boot", icon: "leaf.arrow.triangle.circlepath", defaultPort: 8080, color: Color(hex: "6DB33F")),
        .init(name: "Custom", icon: "slider.horizontal.3", defaultPort: 8080, color: CTColors.brand),
    ]
}

// MARK: - Docker Container
struct DockerContainer: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: [PortMapping]
    
    var isRunning: Bool { status.lowercased().contains("up") }
    
    struct PortMapping: Hashable {
        let hostPort: Int
        let containerPort: Int
        let proto: String
    }
}

// MARK: - MAMP Site
struct MAMPSite: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    var port: Int = 8888
    var vhosts: [VHostEntry] = []
    
    /// A single VirtualHost entry from httpd-vhosts.conf
    struct VHostEntry: Hashable, Identifiable {
        var id: String { "\(serverName):\(port)" }
        let serverName: String
        let port: Int
        let documentRoot: String
    }
}

// MARK: - Log Entry
struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let source: String?
    
    enum LogLevel: String, Codable, CaseIterable {
        case debug, info, warning, error, critical
        
        var color: Color {
            switch self {
            case .debug:    CTColors.textTertiary
            case .info:     CTColors.info
            case .warning:  CTColors.warning
            case .error:    CTColors.danger
            case .critical: Color(hex: "FF0000")
            }
        }
        var icon: String {
            switch self {
            case .debug:    "ladybug"
            case .info:     "info.circle"
            case .warning:  "exclamationmark.triangle"
            case .error:    "xmark.octagon"
            case .critical: "flame"
            }
        }
    }
    
    enum LogCategory: String, Codable, CaseIterable {
        case tunnel, docker, mamp, fileShare, system, network
        
        var displayName: String {
            switch self {
            case .tunnel:    "Tunnel"
            case .docker:    "Docker"
            case .mamp:      "MAMP"
            case .fileShare: "File Share"
            case .system:    "System"
            case .network:   "Network"
            }
        }
    }
    
    init(level: LogLevel, category: LogCategory, message: String, source: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.source = source
    }
}

// MARK: - Backup Data
struct BackupData: Codable {
    let version: String
    let createdAt: Date
    let tunnels: [ManagedTunnel]
    let settings: BackupSettings
    let configFiles: [BackupConfigFile]
    let appVersion: String
    let systemVersion: String
    let deviceName: String
    
    init(version: String, createdAt: Date, tunnels: [ManagedTunnel], settings: BackupSettings,
         configFiles: [BackupConfigFile] = [], appVersion: String = "1.0.0",
         systemVersion: String = "", deviceName: String = "") {
        self.version = version
        self.createdAt = createdAt
        self.tunnels = tunnels
        self.settings = settings
        self.configFiles = configFiles
        self.appVersion = appVersion
        self.systemVersion = systemVersion
        self.deviceName = deviceName
    }
}

struct BackupConfigFile: Codable {
    let fileName: String
    let content: String
    let tunnelUUID: String
}

struct BackupSettings: Codable {
    let cloudflaredPath: String
    let configDirectory: String
    let autoStartTunnels: Bool
    let autoStartMAMP: Bool
    let checkInterval: Double
    let mampBasePath: String
    let mampSitesDir: String
    let mampApacheConfig: String
    let mampVHostConfig: String
    let mampHttpdConf: String
    
    init(cloudflaredPath: String, configDirectory: String, autoStartTunnels: Bool, autoStartMAMP: Bool,
         checkInterval: Double, mampBasePath: String = "/Applications/MAMP",
         mampSitesDir: String = "/Applications/MAMP/htdocs",
         mampApacheConfig: String = "/Applications/MAMP/conf/apache",
         mampVHostConfig: String = "/Applications/MAMP/conf/apache/extra/httpd-vhosts.conf",
         mampHttpdConf: String = "/Applications/MAMP/conf/apache/httpd.conf") {
        self.cloudflaredPath = cloudflaredPath
        self.configDirectory = configDirectory
        self.autoStartTunnels = autoStartTunnels
        self.autoStartMAMP = autoStartMAMP
        self.checkInterval = checkInterval
        self.mampBasePath = mampBasePath
        self.mampSitesDir = mampSitesDir
        self.mampApacheConfig = mampApacheConfig
        self.mampVHostConfig = mampVHostConfig
        self.mampHttpdConf = mampHttpdConf
    }
}

struct BackupFile: Identifiable, Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let size: Int64
    let tunnelCount: Int
}

// MARK: - Navigation
enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard
    case tunnels
    case quickTunnel
    case portScanner
    case docker
    case mamp
    case fileShare
    case liveLog
    case qrCode
    case teamSharing
    case domainMigration
    case history
    case settings
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .dashboard:       NSLocalizedString("nav.dashboard", comment: "")
        case .tunnels:         NSLocalizedString("nav.tunnels", comment: "")
        case .quickTunnel:     NSLocalizedString("nav.quickTunnel", comment: "")
        case .portScanner:     "Port Tarayıcı"
        case .docker:          NSLocalizedString("nav.docker", comment: "")
        case .mamp:            NSLocalizedString("nav.mamp", comment: "")
        case .fileShare:       NSLocalizedString("nav.fileShare", comment: "")
        case .liveLog:         "Canlı Loglar"
        case .qrCode:          "QR Kod"
        case .teamSharing:     "Takım Paylaşımı"
        case .domainMigration: "Domain Yönetimi"
        case .history:         NSLocalizedString("nav.history", comment: "")
        case .settings:        NSLocalizedString("nav.settings", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard:       "square.grid.2x2"
        case .tunnels:         "point.3.connected.trianglepath.dotted"
        case .quickTunnel:     "bolt.horizontal"
        case .portScanner:     "antenna.radiowaves.left.and.right"
        case .docker:          "shippingbox"
        case .mamp:            "server.rack"
        case .fileShare:       "folder.badge.person.crop"
        case .liveLog:         "terminal"
        case .qrCode:          "qrcode"
        case .teamSharing:     "person.3"
        case .domainMigration: "arrow.triangle.2.circlepath"
        case .history:         "clock.arrow.circlepath"
        case .settings:        "gearshape"
        }
    }
    
    var section: NavigationSection {
        switch self {
        case .dashboard:   .main
        case .tunnels, .quickTunnel, .portScanner: .tunnels
        case .docker, .mamp, .fileShare: .services
        case .liveLog, .qrCode, .teamSharing, .domainMigration, .history, .settings: .tools
        }
    }
    
    enum NavigationSection: String, CaseIterable {
        case main, tunnels, services, tools
        
        var title: String {
            switch self {
            case .main:     ""
            case .tunnels:  NSLocalizedString("section.tunnels", comment: "")
            case .services: NSLocalizedString("section.services", comment: "")
            case .tools:    "Araçlar & Sistem"
            }
        }
    }
}
