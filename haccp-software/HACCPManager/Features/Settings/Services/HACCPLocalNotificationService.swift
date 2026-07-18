import Foundation
import UserNotifications
import SwiftData

/// Notifiche locali HACCP collegate a Impostazioni → Notifiche.
@MainActor
enum HACCPLocalNotificationService {
    private static let center = UNUserNotificationCenter.current()
    private static var settings: NotificationSettings { SettingsStorageService.shared.notifications }

    private static let dailySummaryId = "haccp_daily_summary"
    private static let cleaningDailyId = "haccp_cleaning_daily"
    private static let expiryPrefix = "haccp_expiry_"
    private static let tempPrefix = "haccp_temp_"
    private static let cleaningCriticalPrefix = "haccp_cleaning_crit_"

    // MARK: - Authorization

    static func requestAuthorizationIfNeeded() {
        guard settings.notificationsEnabled else { return }
        center.getNotificationSettings { current in
            guard current.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - Temperature

    static func notifyTemperatureAlert(deviceName: String, message: String, recordId: UUID) {
        guard settings.notificationsEnabled, settings.tempAlertsEnabled else { return }
        requestAuthorizationIfNeeded()
        schedule(
            identifier: "\(tempPrefix)\(recordId.uuidString)",
            title: "Temperatura fuori range",
            body: "\(deviceName): \(message)",
            after: 1
        )
    }

    // MARK: - Product expiry

    static func syncProductExpiryAlerts(
        records: [TraceabilityRecord],
        thresholdDays: Int,
        now: Date = Date()
    ) {
        clearPending(prefix: expiryPrefix)
        guard settings.notificationsEnabled, settings.productExpiryAlertsEnabled else { return }
        requestAuthorizationIfNeeded()

        let attention = records.filter {
            ProductExpiryEvaluator.needsExpiryAttention($0, thresholdDays: thresholdDays, now: now)
        }
        guard !attention.isEmpty else { return }

        let expired = attention.filter {
            guard let exp = $0.expiryDate else { return $0.productStatus == .expired }
            return ProductExpiryEvaluator.isExpiredByDate(exp, now: now)
        }.count
        let soon = attention.count - expired

        var parts: [String] = []
        if expired > 0 { parts.append("\(expired) scaduti") }
        if soon > 0 { parts.append("\(soon) in scadenza") }
        let body = parts.isEmpty
            ? "Controlla i prodotti in scadenza."
            : "\(parts.joined(separator: ", ")). Apri Controllo scadenze."

        schedule(
            identifier: "\(expiryPrefix)digest",
            title: "Scadenze prodotti",
            body: body,
            after: 2
        )
    }

    // MARK: - Cleaning

    static func notifyCleaningCriticality(areaName: String, taskName: String, recordId: UUID) {
        guard settings.notificationsEnabled, settings.cleaningRemindersEnabled else { return }
        requestAuthorizationIfNeeded()
        schedule(
            identifier: "\(cleaningCriticalPrefix)\(recordId.uuidString)",
            title: "Pulizia non conforme",
            body: "\(areaName) — \(taskName)",
            after: 1
        )
    }

    static func syncCleaningReminders(pendingCount: Int, nextDueAt: Date? = nil, now: Date = Date()) {
        center.removePendingNotificationRequests(withIdentifiers: [cleaningDailyId])
        guard settings.notificationsEnabled, settings.cleaningRemindersEnabled else { return }
        guard pendingCount > 0 else { return }
        requestAuthorizationIfNeeded()

        let triggerDate: Date
        if let nextDueAt, nextDueAt > now {
            triggerDate = nextDueAt
        } else {
            triggerDate = now.addingTimeInterval(5)
        }

        schedule(
            identifier: cleaningDailyId,
            title: "Pulizie da completare",
            body: pendingCount == 1
                ? "C'è 1 controllo pulizia in sospeso."
                : "Ci sono \(pendingCount) controlli pulizia in sospeso.",
            after: max(2, triggerDate.timeIntervalSince(now))
        )
    }

    // MARK: - Daily summary

    static func syncDailySummary() {
        center.removePendingNotificationRequests(withIdentifiers: [dailySummaryId])
        guard settings.notificationsEnabled, settings.dailyReportSummaryEnabled else { return }
        requestAuthorizationIfNeeded()

        var components = DateComponents()
        components.hour = min(23, max(0, settings.dailySummaryHour))
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Riepilogo HACCP"
        content.body = "Controlla Avvisi e registrazioni del giorno."
        content.sound = settings.soundsEnabled ? .default : nil

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: dailySummaryId, content: content, trigger: trigger))
    }

    // MARK: - Report ready (temperature export)

    static func notifyReportReady(title: String = "Report pronto", body: String) {
        guard settings.notificationsEnabled else { return }
        requestAuthorizationIfNeeded()
        schedule(
            identifier: "haccp_report_\(UUID().uuidString)",
            title: title,
            body: body,
            after: 1
        )
    }

    // MARK: - App-active sync

    static func syncScheduledAlerts(
        modelContext: ModelContext,
        restaurantId: UUID?
    ) {
        syncDailySummary()
        guard let restaurantId else { return }

        let threshold = SettingsStorageService.shared.haccp.productExpiryThreshold
        var traceDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { record in
                record.restaurantId == restaurantId && !record.isArchived
            }
        )
        traceDescriptor.fetchLimit = PerformanceConfig.traceabilityActiveFetchLimit
        let records = (try? modelContext.fetch(traceDescriptor)) ?? []
        syncProductExpiryAlerts(records: records, thresholdDays: threshold)

        var runDescriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { run in
                run.restaurantId == restaurantId
            }
        )
        runDescriptor.fetchLimit = 200
        let runs = (try? modelContext.fetch(runDescriptor)) ?? []
        let pendingCleaning = runs.filter { run in
            let isCleaning = run.templateTitleSnapshot.localizedCaseInsensitiveContains("puliz")
                || run.templateTitleSnapshot.localizedCaseInsensitiveContains("cleaning")
            let open = run.status != .completed && run.status != .failed
                && run.status != .archived && run.status != .missed
            return isCleaning && open
        }
        let nextDue = pendingCleaning.compactMap(\.dueAt).sorted().first
        syncCleaningReminders(pendingCount: pendingCleaning.count, nextDueAt: nextDue)
    }

    // MARK: - Helpers

    private static func schedule(identifier: String, title: String, body: String, after interval: TimeInterval) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = settings.soundsEnabled ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private static func clearPending(prefix: String) {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
