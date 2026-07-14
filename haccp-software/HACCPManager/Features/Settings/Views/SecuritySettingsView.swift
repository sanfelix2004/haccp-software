import SwiftUI

struct SecuritySettingsView: View {
    var storage = SettingsStorageService.shared

    var body: some View {
        @Bindable var storage = storage
        SettingsPanelCard(title: "Protezione app") {
            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: $storage.security.isBiometricsEnabled) {
                    SettingLabel(title: "Biometria", icon: "faceid", description: "Touch ID o Face ID.")
                }
                .onChange(of: storage.security.isBiometricsEnabled) { storage.saveAll() }

                Toggle(isOn: $storage.security.requirePinOnInactivity) {
                    SettingLabel(title: "Blocco inattività", icon: "timer", description: "PIN dopo pausa.")
                }
                .onChange(of: storage.security.requirePinOnInactivity) { storage.saveAll() }

                Toggle(isOn: $storage.security.requireMasterAuthForCriticalActions) {
                    SettingLabel(title: "Protezione MASTER", icon: "lock.shield", description: "Per eliminazioni e reset.")
                }
                .onChange(of: storage.security.requireMasterAuthForCriticalActions) { storage.saveAll() }

                Toggle(isOn: $storage.security.showLastAccess) {
                    SettingLabel(title: "Ultimo accesso", icon: "clock.arrow.circlepath")
                }
                .onChange(of: storage.security.showLastAccess) { storage.saveAll() }
            }
        }
    }
}
