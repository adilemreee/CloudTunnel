// MARK: - Touch Bar Support
// NSTouchBar integration for quick tunnel control

import SwiftUI
import AppKit
import Combine

// MARK: - Touch Bar Identifiers
extension NSTouchBarItem.Identifier {
    static let tunnelStatus = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.tunnelStatus")
    static let startAll = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.startAll")
    static let stopAll = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.stopAll")
    static let quickTunnel = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.quickTunnel")
    static let favoriteTunnels = NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.favoriteTunnels")
}

extension NSTouchBar.CustomizationIdentifier {
    static let cloudTunnel = NSTouchBar.CustomizationIdentifier("com.adilemre.CloudTunnel.touchBar")
}

// MARK: - Touch Bar Provider
@MainActor
class TouchBarController: NSObject, ObservableObject {
    static let shared = TouchBarController()
    
    private var cancellables = Set<AnyCancellable>()
    private var statusButton: NSButton?
    private var favButton: NSButton?
    private var currentTouchBar: NSTouchBar?
    private var windowObserver: Any?
    private lazy var delegateAdapter = TouchBarDelegateAdapter(controller: self)
    
    override init() {
        super.init()
        setupObservers()
    }
    
    // MARK: - State Observation
    private func setupObservers() {
        // Observe tunnel state changes to refresh Touch Bar
        let tunnelService = TunnelService.shared
        tunnelService.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusDisplay()
                }
            }
            .store(in: &cancellables)
        
        // Observe window becoming key to attach Touch Bar
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow,
                  window === NSApp.mainWindow else { return }
            Task { @MainActor in
                self?.attachToWindow(window)
            }
        }
    }
    
    // MARK: - Attach to Window
    func attachToWindow(_ window: NSWindow) {
        if currentTouchBar == nil {
            currentTouchBar = makeTouchBar()
        }
        window.touchBar = currentTouchBar
    }
    
    func attach() {
        if let window = NSApp.mainWindow {
            attachToWindow(window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            Task { @MainActor in
                if let window = NSApp.mainWindow {
                    self?.attachToWindow(window)
                }
            }
        }
    }
    
    // MARK: - Make Touch Bar
    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = delegateAdapter
        touchBar.customizationIdentifier = .cloudTunnel
        touchBar.defaultItemIdentifiers = [
            .tunnelStatus,
            .fixedSpaceSmall,
            .startAll,
            .stopAll,
            .flexibleSpace,
            .favoriteTunnels,
            .fixedSpaceSmall,
            .quickTunnel,
        ]
        touchBar.customizationAllowedItemIdentifiers = [
            .tunnelStatus,
            .startAll,
            .stopAll,
            .favoriteTunnels,
            .quickTunnel,
        ]
        currentTouchBar = touchBar
        return touchBar
    }
    
    // MARK: - Item Factory (called from delegate adapter on main thread)
    func makeItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
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
            if identifier.rawValue.hasPrefix("com.adilemre.CloudTunnel.fav.") {
                return makeFavTunnelButton(identifier)
            }
            return nil
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
        button.bezelColor = running > 0 ? .systemGreen : .systemGray
        button.setAccessibilityIdentifier("statusButton")
        item.view = button
        item.customizationLabel = "Tünel Durumu"
        statusButton = button
        return item
    }
    
    private func makeStartAllItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: "▶ Başlat",
            target: self,
            action: #selector(startAllTapped)
        )
        button.bezelColor = .systemGreen
        item.view = button
        item.customizationLabel = "Tümünü Başlat"
        return item
    }
    
    private func makeStopAllItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: "■ Durdur",
            target: self,
            action: #selector(stopAllTapped)
        )
        button.bezelColor = .systemRed
        item.view = button
        item.customizationLabel = "Tümünü Durdur"
        return item
    }
    
    private func makeQuickTunnelItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(
            title: "⚡ Hızlı",
            target: self,
            action: #selector(quickTunnelTapped)
        )
        button.bezelColor = .systemBlue
        item.view = button
        item.customizationLabel = "Hızlı Tünel"
        return item
    }
    
    private func makeFavoritesItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let tunnelService = TunnelService.shared
        let favorites = tunnelService.favoriteTunnels
        
        if favorites.isEmpty {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "☆ Favori yok", target: nil, action: nil)
            button.bezelColor = .systemGray
            item.view = button
            item.customizationLabel = "Favori Tüneller"
            favButton = button
            return item
        }
        
        let item = NSPopoverTouchBarItem(identifier: identifier)
        item.collapsedRepresentationLabel = "★ \(favorites.count) Favori"
        item.customizationLabel = "Favori Tüneller"
        
        let popoverBar = NSTouchBar()
        popoverBar.delegate = delegateAdapter
        
        var ids: [NSTouchBarItem.Identifier] = []
        for (i, _) in favorites.prefix(5).enumerated() {
            ids.append(NSTouchBarItem.Identifier("com.adilemre.CloudTunnel.fav.\(i)"))
        }
        popoverBar.defaultItemIdentifiers = ids
        item.popoverTouchBar = popoverBar
        
        return item
    }
    
    private func makeFavTunnelButton(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        // Extract index from identifier
        guard let indexStr = identifier.rawValue.components(separatedBy: ".fav.").last,
              let index = Int(indexStr) else { return nil }
        
        let tunnelService = TunnelService.shared
        let favorites = tunnelService.favoriteTunnels
        guard index < favorites.count else { return nil }
        
        let tunnel = favorites[index]
        let item = NSCustomTouchBarItem(identifier: identifier)
        
        let statusEmoji = tunnel.status == .running ? "🟢" : "⚪"
        let button = NSButton(
            title: "\(statusEmoji) \(tunnel.displayName)",
            target: self,
            action: #selector(favoriteTunnelTapped(_:))
        )
        button.tag = index
        button.bezelColor = tunnel.status == .running ? .systemGreen : .systemGray
        item.view = button
        item.customizationLabel = tunnel.displayName
        return item
    }
    
    // MARK: - Update Display (without full rebuild)
    private func updateStatusDisplay() {
        let tunnelService = TunnelService.shared
        let running = tunnelService.totalRunning
        let total = tunnelService.managedTunnels.count
        
        statusButton?.title = "⚡ \(running)/\(total) aktif"
        statusButton?.bezelColor = running > 0 ? .systemGreen : .systemGray
        
        // Update favorites label
        let favCount = tunnelService.favoriteTunnels.count
        if favCount == 0 {
            favButton?.title = "☆ Favori yok"
        }
        
        // Full rebuild only if structure changed (favorite count changed, etc.)
        rebuildTouchBar()
    }
    
    private func rebuildTouchBar() {
        guard let window = NSApp.mainWindow else { return }
        currentTouchBar = nil
        window.touchBar = nil
        let newBar = makeTouchBar()
        window.touchBar = newBar
    }
    
    // MARK: - Actions
    
    @objc private func startAllTapped() {
        Task { @MainActor in
            await TunnelService.shared.startAllTunnels()
        }
    }
    
    @objc private func stopAllTapped() {
        Task { @MainActor in
            await TunnelService.shared.stopAllTunnels()
        }
    }
    
    @objc private func quickTunnelTapped() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .navigateToQuickTunnel, object: nil)
    }
    
    @objc private func favoriteTunnelTapped(_ sender: NSButton) {
        let index = sender.tag
        let tunnelService = TunnelService.shared
        let favorites = tunnelService.favoriteTunnels
        guard index < favorites.count else { return }
        
        let tunnel = favorites[index]
        Task { @MainActor in
            if tunnel.status == .running {
                await tunnelService.stopTunnel(tunnel)
            } else {
                await tunnelService.startTunnel(tunnel)
            }
        }
    }
    
    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cancellables.removeAll()
    }
}

// MARK: - Notification for navigation
extension Notification.Name {
    static let navigateToQuickTunnel = Notification.Name("navigateToQuickTunnel")
}

// MARK: - Touch Bar SwiftUI Modifier
struct TouchBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                TouchBarController.shared.attach()
            }
    }
}

extension View {
    func withTouchBar() -> some View {
        modifier(TouchBarModifier())
    }
}

// MARK: - Touch Bar Delegate Adapter
// Bridges nonisolated NSTouchBarDelegate to @MainActor TouchBarController
class TouchBarDelegateAdapter: NSObject, NSTouchBarDelegate {
    private weak var controller: TouchBarController?
    
    init(controller: TouchBarController) {
        self.controller = controller
        super.init()
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        // NSTouchBar delegate is always called on main thread
        return MainActor.assumeIsolated {
            controller?.makeItem(for: identifier)
        }
    }
}
