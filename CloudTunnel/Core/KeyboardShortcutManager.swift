// MARK: - Keyboard Shortcuts Manager
// Global keyboard shortcut handling with customizable bindings

import SwiftUI
import Carbon.HIToolbox
import Combine

@MainActor
final class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    // MARK: - Published State
    @Published var shortcuts: [ShortcutAction] = ShortcutAction.defaults
    
    // Event monitors
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    private init() {
        loadShortcuts()
        setupMonitors()
    }
    
    // MARK: - Shortcut Action
    struct ShortcutAction: Identifiable, Codable, Equatable {
        let id: String
        let name: String
        let icon: String
        var key: String
        var modifiers: [ModifierKey]
        let category: Category
        
        enum Category: String, Codable, CaseIterable {
            case tunnel = "Tüneller"
            case navigation = "Navigasyon"
            case general = "Genel"
        }
        
        enum ModifierKey: String, Codable {
            case command = "⌘"
            case shift = "⇧"
            case option = "⌥"
            case control = "⌃"
            
            var nsFlag: NSEvent.ModifierFlags {
                switch self {
                case .command: .command
                case .shift:   .shift
                case .option:  .option
                case .control: .control
                }
            }
        }
        
        var displayShortcut: String {
            modifiers.map(\.rawValue).joined() + key.uppercased()
        }
        
        var nsModifiers: NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            for mod in modifiers {
                flags.insert(mod.nsFlag)
            }
            return flags
        }
        
        static let defaults: [ShortcutAction] = [
            // Tunnel shortcuts
            ShortcutAction(id: "quick_tunnel", name: "Hızlı Tünel Başlat", icon: "bolt.horizontal.fill",
                          key: "t", modifiers: [.command, .shift], category: .tunnel),
            ShortcutAction(id: "stop_all", name: "Tüm Tünelleri Durdur", icon: "stop.circle.fill",
                          key: "s", modifiers: [.command, .shift], category: .tunnel),
            ShortcutAction(id: "start_all", name: "Tüm Tünelleri Başlat", icon: "play.circle.fill",
                          key: "r", modifiers: [.command, .shift], category: .tunnel),
            ShortcutAction(id: "scan_configs", name: "Config Dosyalarını Tara", icon: "arrow.clockwise",
                          key: "f", modifiers: [.command, .shift], category: .tunnel),
            
            // Navigation shortcuts
            ShortcutAction(id: "nav_dashboard", name: "Dashboard", icon: "square.grid.2x2",
                          key: "1", modifiers: [.command], category: .navigation),
            ShortcutAction(id: "nav_tunnels", name: "Tüneller", icon: "point.3.connected.trianglepath.dotted",
                          key: "2", modifiers: [.command], category: .navigation),
            ShortcutAction(id: "nav_quick", name: "Hızlı Tünel", icon: "bolt.horizontal",
                          key: "3", modifiers: [.command], category: .navigation),
            ShortcutAction(id: "nav_ports", name: "Port Tarayıcı", icon: "antenna.radiowaves.left.and.right",
                          key: "4", modifiers: [.command], category: .navigation),
            ShortcutAction(id: "nav_logs", name: "Canlı Loglar", icon: "terminal",
                          key: "5", modifiers: [.command], category: .navigation),
            ShortcutAction(id: "nav_settings", name: "Ayarlar", icon: "gearshape",
                          key: ",", modifiers: [.command], category: .navigation),
            
            // General shortcuts
            ShortcutAction(id: "scan_ports", name: "Portları Tara", icon: "magnifyingglass",
                          key: "p", modifiers: [.command, .shift], category: .general),
            ShortcutAction(id: "generate_qr", name: "QR Kod Oluştur", icon: "qrcode",
                          key: "q", modifiers: [.command, .shift], category: .general),
        ]
    }
    
    // MARK: - Event Monitors
    private func setupMonitors() {
        // Local event monitor (when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handleKeyEvent(event) {
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        for shortcut in shortcuts {
            if shortcut.key.lowercased() == key && flags == shortcut.nsModifiers {
                executeAction(shortcut.id)
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Execute Action
    func executeAction(_ actionID: String) {
        switch actionID {
        case "quick_tunnel":
            NotificationCenter.default.post(name: .navigateToQuickTunnel, object: nil)
            
        case "stop_all":
            Task { await TunnelService.shared.stopAllTunnels() }
            
        case "start_all":
            Task { await TunnelService.shared.startAllTunnels() }
            
        case "scan_configs":
            TunnelService.shared.scanConfigFiles()
            
        case "nav_dashboard":
            postNavigation(.dashboard)
        case "nav_tunnels":
            postNavigation(.tunnels)
        case "nav_quick":
            postNavigation(.quickTunnel)
        case "nav_ports":
            postNavigation(.portScanner)
        case "nav_logs":
            postNavigation(.liveLog)
        case "nav_settings":
            postNavigation(.settings)
            
        case "scan_ports":
            Task { await PortScannerService.shared.scanPorts() }
            postNavigation(.portScanner)
            
        case "generate_qr":
            postNavigation(.qrCode)
            
        default:
            break
        }
    }
    
    private func postNavigation(_ item: NavigationItem) {
        NotificationCenter.default.post(name: .navigateToItem, object: item)
    }
    
    // MARK: - Persistence
    private func loadShortcuts() {
        guard let data = UserDefaults.standard.data(forKey: "customShortcuts"),
              let saved = try? JSONDecoder().decode([ShortcutAction].self, from: data) else {
            return
        }
        shortcuts = saved
    }
    
    func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: "customShortcuts")
        }
    }
    
    func resetToDefaults() {
        shortcuts = ShortcutAction.defaults
        saveShortcuts()
    }
    
    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToItem = Notification.Name("navigateToItem")
}
