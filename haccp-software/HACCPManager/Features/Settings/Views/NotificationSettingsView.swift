import SwiftUI

struct NotificationSettingsView: View {
    var storage = SettingsStorageService.shared
    
    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: 32) {
            
            Toggle(isOn: $storage.notifications.notificationsEnabled) {
                SettingLabel(title: "Notifiche di Sistema", icon: "bell.badge.fill", description: "Abilita tutti gli avvisi HACCP.")
            }
            .padding()
            .background(ThemeManager.shared.colorDivider)
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Canali Notifica")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                
                Group {
                    Toggle("Allarmi Temperature", isOn: $storage.notifications.tempAlertsEnabled)
                    Toggle("Promemoria Checklist", isOn: $storage.notifications.checklistRemindersEnabled)
                    Toggle("Scadenze Prodotti", isOn: $storage.notifications.productExpiryAlertsEnabled)
                    Toggle("Riepilogo Serale", isOn: $storage.notifications.dailyReportSummaryEnabled)
                }
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                .disabled(!storage.notifications.notificationsEnabled)
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Feedback")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                
                Toggle("Suoni", isOn: $storage.notifications.soundsEnabled)
                Toggle("Vibrazione", isOn: $storage.notifications.hapticsEnabled)
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
            .onChange(of: storage.notifications.notificationsEnabled) { storage.saveAll() }
            .onChange(of: storage.notifications.tempAlertsEnabled) { storage.saveAll() }
        }
    }
}
