import SwiftUI

struct HACCPSettingsView: View {
    var storage = SettingsStorageService.shared
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: theme.spacing.lg) {
            HACCPTemperatureSection(storage: storage)
            HACCPOilSection(storage: storage)
            HACCPDefrostSection(storage: storage)
            HACCPOperativitySection(storage: storage)
            HACCPGroqSection(storage: storage)
        }
    }
}

private struct HACCPTemperatureSection: View {
    @Bindable var storage: SettingsStorageService

    var body: some View {
        SettingsPanelCard(title: "Temperature", caption: "Range consentiti e frequenza controlli.") {
            VStack(spacing: 12) {
                SettingsCompactNumberRow(title: "Frigo min", value: $storage.haccp.fridgeMinTemp, unit: "°C")
                SettingsCompactNumberRow(title: "Frigo max", value: $storage.haccp.fridgeMaxTemp, unit: "°C")
                SettingsCompactNumberRow(title: "Freezer min", value: $storage.haccp.freezerMinTemp, unit: "°C")
                SettingsCompactNumberRow(title: "Freezer max", value: $storage.haccp.freezerMaxTemp, unit: "°C")
                SettingsCompactNumberRow(title: "Abbattitore", value: $storage.haccp.blastChillerTemp, unit: "°C")
                SettingsCompactNumberRow(
                    title: "Soglia avviso",
                    value: Binding(
                        get: { storage.haccp.warningThreshold ?? 0.8 },
                        set: { storage.haccp.warningThreshold = $0 }
                    ),
                    unit: "°C"
                )
                SettingsCompactStepperRow(
                    title: "Controlli ogni",
                    value: $storage.haccp.tempCheckFrequency,
                    range: 1...24,
                    unit: "h"
                )
            }
        }
        .onChange(of: storage.haccp.fridgeMinTemp) { storage.saveAll() }
        .onChange(of: storage.haccp.fridgeMaxTemp) { storage.saveAll() }
        .onChange(of: storage.haccp.freezerMinTemp) { storage.saveAll() }
        .onChange(of: storage.haccp.freezerMaxTemp) { storage.saveAll() }
        .onChange(of: storage.haccp.blastChillerTemp) { storage.saveAll() }
        .onChange(of: storage.haccp.tempCheckFrequency) { storage.saveAll() }
        .onChange(of: storage.haccp.warningThreshold) { storage.saveAll() }
    }
}

private struct HACCPOilSection: View {
    @Bindable var storage: SettingsStorageService
    @Environment(\.theme) private var theme

    var body: some View {
        SettingsPanelCard(title: "Olio", caption: "Soglie polarità e foto in non conformità.") {
            VStack(spacing: 12) {
                SettingsCompactNumberRow(title: "Attenzione", value: $storage.haccp.oilPolarAttentionLimit, unit: "%")
                SettingsCompactNumberRow(title: "Massimo", value: $storage.haccp.oilPolarMaximumLimit, unit: "%")
                Toggle("Foto obbligatoria se non conforme", isOn: $storage.haccp.oilNonCompliancePhotoRequired)
                    .font(theme.typography.subheadline)
            }
        }
        .onChange(of: storage.haccp.oilPolarAttentionLimit) { storage.saveAll() }
        .onChange(of: storage.haccp.oilPolarMaximumLimit) { storage.saveAll() }
        .onChange(of: storage.haccp.oilNonCompliancePhotoRequired) { storage.saveAll() }
    }
}

private struct HACCPDefrostSection: View {
    @Bindable var storage: SettingsStorageService

    var body: some View {
        SettingsExpandableCard(title: "Scongelamento", caption: "Tempi consigliati per metodo") {
            VStack(spacing: 12) {
                SettingsCompactStepperRow(
                    title: DefrostMethod.frigorifero.label,
                    value: $storage.haccp.defrostFridgeRecommendedHours,
                    range: 6...72,
                    unit: "h"
                )
                SettingsCompactStepperRow(
                    title: DefrostMethod.temperaturaControllata.label,
                    value: $storage.haccp.defrostControlledTempRecommendedHours,
                    range: 2...48,
                    unit: "h"
                )
                SettingsCompactStepperRow(
                    title: DefrostMethod.acquaFredda.label,
                    value: $storage.haccp.defrostColdWaterRecommendedHours,
                    range: 1...12,
                    unit: "h"
                )
                SettingsCompactStepperRow(
                    title: DefrostMethod.fornoMicroonde.label,
                    value: $storage.haccp.defrostMicrowaveRecommendedHours,
                    range: 1...8,
                    unit: "h"
                )
                SettingsCompactStepperRow(
                    title: DefrostMethod.altro.label,
                    value: $storage.haccp.defrostOtherRecommendedHours,
                    range: 6...72,
                    unit: "h"
                )
            }
        }
        .onChange(of: storage.haccp.defrostFridgeRecommendedHours) { storage.saveAll() }
        .onChange(of: storage.haccp.defrostControlledTempRecommendedHours) { storage.saveAll() }
        .onChange(of: storage.haccp.defrostColdWaterRecommendedHours) { storage.saveAll() }
        .onChange(of: storage.haccp.defrostMicrowaveRecommendedHours) { storage.saveAll() }
        .onChange(of: storage.haccp.defrostOtherRecommendedHours) { storage.saveAll() }
    }
}

private struct HACCPOperativitySection: View {
    @Bindable var storage: SettingsStorageService
    @Environment(\.theme) private var theme

    var body: some View {
        SettingsPanelCard(title: "Operatività") {
            VStack(spacing: 12) {
                SettingsCompactStepperRow(
                    title: "Avviso scadenze",
                    value: $storage.haccp.productExpiryThreshold,
                    range: 1...15,
                    unit: "gg"
                )
                Text("In tracciabilità la foto etichetta è obbligatoria; il codice lotto è opzionale se assente sull'etichetta.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                SettingsCompactStepperRow(
                    title: "Conservazione dati",
                    value: $storage.haccp.storageDurationYears,
                    range: 1...10,
                    unit: "anni"
                )
            }
        }
        .onChange(of: storage.haccp.productExpiryThreshold) { storage.saveAll() }
        .onChange(of: storage.haccp.storageDurationYears) { storage.saveAll() }
    }
}

private struct HACCPGroqSection: View {
    @Bindable var storage: SettingsStorageService
    @Environment(\.theme) private var theme

    private var groqKeyBinding: Binding<String> {
        Binding(
            get: { storage.haccp.groqApiKey ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                storage.haccp.groqApiKey = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    var body: some View {
        SettingsExpandableCard(title: "Lettura lotti AI", caption: "Chiave Groq opzionale per OCR etichette") {
            VStack(alignment: .leading, spacing: 12) {
                if GroqApiKeyService.bundledFallbackKey() != nil {
                    Label("Chiave di riserva attiva", systemImage: "checkmark.shield.fill")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorSuccess)
                }
                Text("Crea o aggiorna la chiave su console.groq.com.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                SecureField("Chiave API Groq", text: groqKeyBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .onChange(of: storage.haccp.groqApiKey) { storage.saveAll() }
    }
}
