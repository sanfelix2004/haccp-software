import SwiftUI

struct NotificationSettingsView: View {
    var storage = SettingsStorageService.shared
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var storage = storage
        SettingsPanelCard(title: "Notifiche", caption: "Avvisi HACCP e feedback") {
            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: $storage.notifications.notificationsEnabled) {
                    SettingLabel(title: "Notifiche attive", icon: "bell.badge.fill")
                }

                if storage.notifications.notificationsEnabled {
                    VStack(alignment: .leading, spacing: 14) {
                        notificationToggle("Temperature", keyPath: \.tempAlertsEnabled)
                        notificationToggle("Checklist", keyPath: \.checklistRemindersEnabled)
                        notificationToggle("Scadenze prodotti", keyPath: \.productExpiryAlertsEnabled)
                        notificationToggle("Backup iCloud", keyPath: \.iCloudBackupAlertsEnabled)
                        notificationToggle("Riepilogo serale", keyPath: \.dailyReportSummaryEnabled)
                    }
                    .padding(.leading, 4)
                }

                Divider()

                HStack(spacing: 24) {
                    Toggle("Suoni", isOn: $storage.notifications.soundsEnabled)
                    Toggle("Vibrazione", isOn: $storage.notifications.hapticsEnabled)
                }
                .font(theme.typography.subheadline)
                .disabled(!storage.notifications.notificationsEnabled)
            }
        }
        .onChange(of: storage.notifications.notificationsEnabled) { storage.saveAll() }
        .onChange(of: storage.notifications.tempAlertsEnabled) { storage.saveAll() }
        .onChange(of: storage.notifications.checklistRemindersEnabled) { storage.saveAll() }
        .onChange(of: storage.notifications.productExpiryAlertsEnabled) { storage.saveAll() }
        .onChange(of: storage.notifications.iCloudBackupAlertsEnabled) { storage.saveAll() }
        .onChange(of: storage.notifications.dailyReportSummaryEnabled) { storage.saveAll() }
        .onChange(of: storage.notifications.soundsEnabled) { storage.saveAll() }
        .onChange(of: storage.notifications.hapticsEnabled) { storage.saveAll() }
    }

    @ViewBuilder
    private func notificationToggle(_ title: String, keyPath: WritableKeyPath<NotificationSettings, Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { storage.notifications[keyPath: keyPath] },
            set: { storage.notifications[keyPath: keyPath] = $0 }
        ))
        .font(theme.typography.subheadline)
    }
}
