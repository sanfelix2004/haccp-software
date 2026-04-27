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
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Canali Notifica")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Group {
                    Toggle("Allarmi Temperature", isOn: $storage.notifications.tempAlertsEnabled)
                    Toggle("Promemoria Checklist", isOn: $storage.notifications.checklistRemindersEnabled)
                    Toggle("Scadenze Prodotti", isOn: $storage.notifications.productExpiryAlertsEnabled)
                    Toggle("Riepilogo Serale", isOn: $storage.notifications.dailyReportSummaryEnabled)
                }
                .foregroundColor(.white)
                .disabled(!storage.notifications.notificationsEnabled)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Feedback")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Toggle("Suoni", isOn: $storage.notifications.soundsEnabled)
                Toggle("Vibrazione", isOn: $storage.notifications.hapticsEnabled)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .onChange(of: storage.notifications.notificationsEnabled) { storage.saveAll() }
            .onChange(of: storage.notifications.tempAlertsEnabled) { storage.saveAll() }
        }
    }
}
