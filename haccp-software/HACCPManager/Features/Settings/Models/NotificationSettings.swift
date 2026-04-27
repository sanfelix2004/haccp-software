import Foundation

public struct NotificationSettings: Codable {
    var notificationsEnabled: Bool = true
    var tempAlertsEnabled: Bool = true
    var checklistRemindersEnabled: Bool = true
    var cleaningRemindersEnabled: Bool = true
    var productExpiryAlertsEnabled: Bool = true
    var dailyReportSummaryEnabled: Bool = true
    var soundsEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var dailySummaryHour: Int = 21 // 21:00
}
