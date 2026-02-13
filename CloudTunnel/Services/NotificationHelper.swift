// MARK: - Notification Helper
// Sends macOS notifications for tunnel events

import Foundation
import UserNotifications

enum NotificationHelper {
    
    /// Request notification permission from the user
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                HistoryService.shared.logFromBackground(.error, .system, "Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Send a notification if the relevant preference is enabled
    static func send(title: String, body: String, category: NotificationCategory) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        
        // Check per-category toggle
        switch category {
        case .tunnelStarted:
            guard UserDefaults.standard.bool(forKey: "notifyOnTunnelStart") else { return }
        case .tunnelStopped:
            guard UserDefaults.standard.bool(forKey: "notifyOnTunnelStop") else { return }
        case .error:
            guard UserDefaults.standard.bool(forKey: "notifyOnError") else { return }
        case .info:
            break // Always send info if notifications are enabled
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    enum NotificationCategory {
        case tunnelStarted
        case tunnelStopped
        case error
        case info
    }
}
