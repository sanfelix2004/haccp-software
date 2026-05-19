import SwiftUI

struct SecuritySettingsView: View {
    var storage = SettingsStorageService.shared
    private var theme: ThemeManager { ThemeManager.shared }

    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: $storage.security.isBiometricsEnabled) {
                    SettingLabel(title: "Biometria", icon: "faceid", description: "Usa Touch ID o Face ID per azioni rapide.")
                }
                .onChange(of: storage.security.isBiometricsEnabled) { storage.saveAll() }

                Divider().background(theme.colorDivider)

                Toggle(isOn: $storage.security.requirePinOnInactivity) {
                    SettingLabel(title: "Blocco Inattività", icon: "timer", description: "Richiedi PIN dopo un periodo di inattività.")
                }
                .onChange(of: storage.security.requirePinOnInactivity) { storage.saveAll() }

                Divider().background(theme.colorDivider)

                Toggle(isOn: $storage.security.requireMasterAuthForCriticalActions) {
                    SettingLabel(title: "Protezione MASTER", icon: "lock.shield", description: "Richiedi autorizzazione per eliminazioni e reset.")
                }
                .onChange(of: storage.security.requireMasterAuthForCriticalActions) { storage.saveAll() }

                Divider().background(theme.colorDivider)

                Toggle(isOn: $storage.security.showLastAccess) {
                    SettingLabel(title: "Registro Accessi", icon: "clock.arrow.circlepath", description: "Mostra l'ultimo accesso effettuato.")
                }
                .onChange(of: storage.security.showLastAccess) { storage.saveAll() }
            }
            .padding()
            .background(theme.colorSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.colorDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
