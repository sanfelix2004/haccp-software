import Foundation
import UserNotifications

@MainActor
enum ICloudSyncNotificationService {
    private static let center = UNUserNotificationCenter.current()
    private static let settings = SettingsStorageService.shared

    static func notifyMonthlyArchiveSynced(
        restaurantName: String,
        copiedCount: Int,
        failedCount: Int,
        referenceDate: Date = Date()
    ) {
        guard settings.notifications.notificationsEnabled,
              settings.notifications.iCloudBackupAlertsEnabled else { return }

        requestAuthorizationIfNeeded()

        let monthLabel = archivedMonthLabel(reference: referenceDate)
        let content = UNMutableNotificationContent()
        content.sound = settings.notifications.soundsEnabled ? .default : nil

        switch (copiedCount, failedCount) {
        case (0, 0):
            content.title = "Backup iCloud aggiornato"
            content.body = "L'archivio di \(monthLabel) di \(restaurantName) è già su iCloud Drive."
        case (_, 0):
            content.title = "Backup iCloud completato"
            content.body = "Archivio di \(monthLabel) di \(restaurantName) sincronizzato su iCloud (\(copiedCount) PDF)."
        case (0, _):
            content.title = "Backup iCloud non riuscito"
            content.body = "L'archivio di \(monthLabel) di \(restaurantName) non è stato copiato su iCloud."
        default:
            content.title = "Backup iCloud parziale"
            content.body = "Archivio di \(monthLabel): \(copiedCount) PDF copiati, \(failedCount) non riusciti."
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "icloud_monthly_\(restaurantName)_\(monthLabel)"
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private static func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { current in
            guard current.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// Mese chiuso appena archiviato (es. a inizio febbraio → «gennaio 2026»).
    private static func archivedMonthLabel(reference: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let archivedMonth = calendar.date(byAdding: .month, value: -1, to: reference) ?? reference
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: archivedMonth)
    }
}
