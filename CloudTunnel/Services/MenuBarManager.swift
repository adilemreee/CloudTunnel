// MARK: - Menu Bar Manager
// NSStatusItem-based menu bar widget for quick tunnel control

import SwiftUI
import AppKit
import Combine

@MainActor
final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    
    private init() {
        setupStatusItem()
        observeTunnelChanges()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "CloudTunnel")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 352, height: 500)
        popover.behavior = .transient
        popover.animates = true
        
        let popoverView = MenuBarPopoverView()
            .environmentObject(TunnelService.shared)
            .environmentObject(MAMPService.shared)
        
        popover.contentViewController = NSHostingController(rootView: popoverView)
        self.popover = popover
    }
    
    // MARK: - Toggle
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        if let popover, popover.isShown {
            popover.performClose(sender)
            removeEventMonitor()
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            addEventMonitor()
        }
    }
    
    // MARK: - Event Monitor (close on outside click)
    
    private func addEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
            self?.removeEventMonitor()
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    // MARK: - Observe Tunnel Changes
    
    private func observeTunnelChanges() {
        TunnelService.shared.$managedTunnels
            .combineLatest(TunnelService.shared.$quickTunnels)
            .receive(on: RunLoop.main)
            .sink { [weak self] managed, quick in
                self?.updateIcon(managed: managed, quick: quick)
            }
            .store(in: &cancellables)
    }
    
    private func updateIcon(managed: [ManagedTunnel], quick: [QuickTunnel]) {
        let runningCount = managed.filter { $0.status == .running }.count + quick.filter { $0.status == .running }.count
        let hasErrors = managed.contains { $0.status == .error }
        
        guard let button = statusItem?.button else { return }
        
        if hasErrors {
            button.image = NSImage(systemSymbolName: "cloud.bolt.fill", accessibilityDescription: "CloudTunnel - Error")
        } else if runningCount > 0 {
            button.image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "CloudTunnel - \(runningCount) Active")
        } else {
            button.image = NSImage(systemSymbolName: "cloud", accessibilityDescription: "CloudTunnel - Idle")
        }
        button.image?.size = NSSize(width: 18, height: 18)
        
        // Badge
        if runningCount > 0 {
            statusItem?.button?.title = " \(runningCount)"
        } else {
            statusItem?.button?.title = ""
        }
    }
}
