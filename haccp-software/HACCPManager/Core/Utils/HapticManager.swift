import SwiftUI
import UIKit

struct HapticManager {
    static let shared = HapticManager()
    
    private init() {}

    private var isEnabled: Bool {
        let notifications = SettingsStorageService.shared.notifications
        return notifications.notificationsEnabled && notifications.hapticsEnabled
    }
    
    func trigger(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
