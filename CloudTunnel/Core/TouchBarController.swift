// MARK: - Touch Bar Support
// NSTouchBar integration for quick tunnel control

import SwiftUI
import AppKit

// MARK: - Touch Bar Identifiers
extension NSTouchBarItem.Identifier {
    static let tunnelStatus = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.tunnelStatus")
    static let startAll = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.startAll")
    static let stopAll = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.stopAll")
    static let quickTunnel = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.quickTunnel")
    static let tunnelGroup = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.tunnelGroup")
    static let favoriteTunnels = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.favoriteTunnels")
}

extension NSTouchBar.CustomizationIdentifier {
    static let cloudTunnel = NSTouchBar.CustomizationIdentifier("com.adilemre.CloudTunnel.touchBar")
}

// MARK: - Touch Bar Provider
@MainActor
class TouchBarController: NSObject, NSTouchBarDelegate, ObservableObject {
    static let shared = TouchBarController()
    
    private var statusObserver: NSKeyValueObservation?
    
    override init() {
        super.init()
    }
    
    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = .cloudTunnel
        touchBar.defaultItemIdentifiers = [
            .tunnelStatus,
            .fixedSpaceLarge,
            .startAll,
            .stopAll,
            .fixedSpaceLarge,
            .favoriteTunnels,
        ]
        touchBar.customizationAllowedItemIdentifiers = [
            .tunnelStatus,
            .startAll,
            .stopAll,
            .favoriteTunnels,
            .quickTunnel,
        ]
        return touchBar
    }
    
    // MARK: - NSTouchBarDelegate
    nonisolated func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        // NSTouchBarDelegate methods are called on main thread in practice
        // Use MainActor.assumeIsolated for safety
        return MainActor.assumeIsolated {
            switch identifier {
            case .tunnelStatus:
                return makeStatusItem(identifier)
            case .startAll:
                return makeStartAllItem(identifier)
            case .stopAll:
                return makeStopAllItem(identifier)
            case .quickTunnel:
                return makeQuickTunnelItem(identifier)
            case .favoriteTunnels:
                return makeFavoritesItem(identifier)
            default:
                return nil
            }
        }
    }
    
    // MARK: - Touch Bar Items
    
    private func makeStatusItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let tunnelService = TunnelService.shared
        let running = tunnelService.totalRunning
        let total = tunnelService.managedTunnels.count
        
        let button = NSButton(
            title: "⚡ \(running)/\(total) aktif",
            target: nil,
            action: nil
        )
        button.bezelColor = running > 0 ? NSColor.systemGreen : NSColor.systemGray
        item.view = button
        item.customizationLabel = "Tünel Durumu"
        return item
    }
    
    private func makeStartAllItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: "▶ Tümünü Başlat",
            target: self,
            action: #selector(startAllTapped)
        )
        button.bezelColor = NSColor.systemGreen
        item.view = button
        item.customizationLabel = "Tümünü Başlat"
        return item
    }
    
    private func makeStopAllItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: "■ Tümünü Durdur",
            target: self,
            action: #selector(stopAllTapped)
        )
        button.bezelColor = NSColor.systemRed
        item.view = button
        item.customizationLabel = "Tümünü Durdur"
        return item
    }
    
    private func makeQuickTunnelItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: "⚡ Hızlı Tünel",
            target: self,
            action: #selector(quickTunnelTapped)
        )
        button.bezelColor = NSColor.systemBlue
        item.view = button
        item.customizationLabel = "Hızlı Tünel"
        return item
    }
    
    private func makeFavoritesItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let tunnelService = TunnelService.shared
        let favorites = tunnelService.favoriteTunnels
        
        if favorites.isEmpty {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                title: "☆ Favori yok",
                target: nil,
                action: nil
            )
            button.bezelColor = NSColor.systemGray
            item.view = button
            item.customizationLabel = "Favori Tüneller"
            return item
        }
        
        // Create a scrubber/popover for favorites
        let item = NSPopoverTouchBarItem(identifier: identifier)
        item.collapsedRepresentationLabel = "★ Favoriler (\(favorites.count))"
        item.customizationLabel = "Favori Tüneller"
        
        let popoverBar = NSTouchBar()
        popoverBar.delegate = self
        
        var buttonIdentifiers: [NSTouchBarItem.Identifier] = []
        for (index, tunnel) in favorites.prefix(5).enumerated() {
            let favId = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.fav.\(index)")
            buttonIdentifiers.append(favId)
            
            // Store tunnel reference
            favoriteTunnelMap[favId] = tunnel
        }
        popoverBar.defaultItemIdentifiers = buttonIdentifiers
        item.popoverTouchBar = popoverBar
        
        return item
    }
    
    // Tunnel map for favorite touch bar items
    private var favoriteTunnelMap: [NSTouchBarItem.Identifier: ManagedTunnel] = [:]
    
    // MARK: - Actions
    
    @objc private func startAllTapped() {
        Task { @MainActor in
            await TunnelService.shared.startAllTunnels()
            refreshTouchBar()
        }
    }
    
    @objc private func stopAllTapped() {
        Task { @MainActor in
            await TunnelService.shared.stopAllTunnels()
            refreshTouchBar()
        }
    }
    
    @objc private func quickTunnelTapped() {
        // Bring app to front and switch to Quick Tunnel view
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .navigateToQuickTunnel, object: nil)
    }
    
    @objc private func toggleFavoriteTunnel(_ sender: NSButton) {
        let idString = sender.accessibilityIdentifier() ?? ""
        let identifier = NSTouchBarItem.Identifier(rawValue: idString)
        guard let tunnel = favoriteTunnelMap[identifier] else { return }
        
        Task { @MainActor in
            let tunnelService = TunnelService.shared
            if tunnel.status == .running {
                await tunnelService.stopTunnel(tunnel)
            } else {
                await tunnelService.startTunnel(tunnel)
            }
            refreshTouchBar()
        }
    }
    
    // MARK: - Refresh
    func refreshTouchBar() {
        guard let window = NSApp.mainWindow else { return }
        window.touchBar = nil // Force recreation
        window.touchBar = makeTouchBar()
    }
}

// MARK: - Notification for navigation
extension Notification.Name {
    static let navigateToQuickTunnel = Notification.Name("navigateToQuickTunnel")
}

// MARK: - Touch Bar Window Integration
extension NSWindow {
    @objc func cloudTunnel_makeTouchBar() -> NSTouchBar? {
        return TouchBarController.shared.makeTouchBar()
    }
}

// MARK: - Touch Bar Modifier for SwiftUI
struct TouchBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let window = NSApp.mainWindow {
                        window.touchBar = TouchBarController.shared.makeTouchBar()
                    }
                }
            }
    }
}

extension View {
    func withTouchBar() -> some View {
        modifier(TouchBarModifier())
    }
}
