import Foundation
import UserNotifications

@MainActor
final class ChecklistNotificationService {
    private let center = UNUserNotificationCenter.current()
    private let settings = SettingsStorageService.shared

    func requestAuthorizationIfNeeded() {
        guard settings.notifications.notificationsEnabled, settings.notifications.checklistRemindersEnabled else { return }
        center.getNotificationSettings { current in
            guard current.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    func syncNotifications(for runs: [ChecklistRun], now: Date = Date()) {
        guard settings.notifications.notificationsEnabled, settings.notifications.checklistRemindersEnabled else {
            clearAllChecklistNotifications()
            return
        }

        requestAuthorizationIfNeeded()

        for run in runs {
            let dueId = notificationId(for: run.id, type: "scadenza")
            let overdueId = notificationId(for: run.id, type: "ritardo")

            if run.status == .completed || run.status == .failed || run.status == .archived {
                center.removePendingNotificationRequests(withIdentifiers: [dueId, overdueId])
                continue
            }

            guard let dueAt = run.dueAt else { continue }
            scheduleNotification(
                identifier: dueId,
                title: "Checklist da completare",
                body: "\(run.templateTitleSnapshot) da completare",
                triggerDate: dueAt > now ? dueAt : now.addingTimeInterval(5)
            )

            if dueAt < now || run.status == .overdue {
                scheduleNotification(
                    identifier: overdueId,
                    title: "Checklist in ritardo",
                    body: "\(run.templateTitleSnapshot) in ritardo",
                    triggerDate: now.addingTimeInterval(6)
                )
            } else {
                let overdueTrigger = dueAt.addingTimeInterval(30 * 60)
                scheduleNotification(
                    identifier: overdueId,
                    title: "Checklist in ritardo",
                    body: "\(run.templateTitleSnapshot) in ritardo",
                    triggerDate: overdueTrigger
                )
            }
        }
    }

    private func scheduleNotification(identifier: String, title: String, body: String, triggerDate: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = settings.notifications.soundsEnabled ? .default : nil

        let interval = max(2, triggerDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func clearAllChecklistNotifications() {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("checklist_") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func notificationId(for runId: UUID, type: String) -> String {
        "checklist_\(runId.uuidString)_\(type)"
    }
}
