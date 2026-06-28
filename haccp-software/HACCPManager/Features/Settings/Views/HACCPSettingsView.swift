import SwiftUI

struct HACCPSettingsView: View {
    var storage = SettingsStorageService.shared
    
    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: 32) {
            
            // Temperature Grids
            VStack(alignment: .leading, spacing: 24) {
                Text("Range Temperature")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                
                HStack(spacing: 20) {
                    TempConfigBox(title: "Frigo (Min)", value: $storage.haccp.fridgeMinTemp, unit: "°C")
                    TempConfigBox(title: "Frigo (Max)", value: $storage.haccp.fridgeMaxTemp, unit: "°C")
                }

                HStack(spacing: 20) {
                    TempConfigBox(title: "Freezer (Min)", value: $storage.haccp.freezerMinTemp, unit: "°C")
                    TempConfigBox(title: "Freezer (Max)", value: $storage.haccp.freezerMaxTemp, unit: "°C")
                }
                
                HStack(spacing: 20) {
                    TempConfigBox(title: "Abbattitore", value: $storage.haccp.blastChillerTemp, unit: "°C")
                    TempConfigBox(title: "Frequenza", value: Binding(get: { Double(storage.haccp.tempCheckFrequency) }, set: { storage.haccp.tempCheckFrequency = Int($0) }), unit: "h")
                }

                TempConfigBox(
                    title: "Warning Threshold",
                    value: Binding(
                        get: { storage.haccp.warningThreshold ?? 0.8 },
                        set: { storage.haccp.warningThreshold = $0 }
                    ),
                    unit: "°C"
                )
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 20) {
                Text("Controllo olio")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)

                HStack(spacing: 20) {
                    TempConfigBox(title: "Limite attenzione", value: $storage.haccp.oilPolarAttentionLimit, unit: "%")
                    TempConfigBox(title: "Limite massimo", value: $storage.haccp.oilPolarMaximumLimit, unit: "%")
                }

                Toggle("Foto obbligatoria per non conformità olio", isOn: $storage.haccp.oilNonCompliancePhotoRequired)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Decongelamento")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)

                Text("Durata massima consigliata per metodo. Oltre questa soglia il processo passa a «In ritardo».")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)

                DefrostDurationStepper(
                    title: DefrostMethod.frigorifero.label,
                    value: $storage.haccp.defrostFridgeRecommendedHours,
                    range: 6...72
                )
                DefrostDurationStepper(
                    title: DefrostMethod.temperaturaControllata.label,
                    value: $storage.haccp.defrostControlledTempRecommendedHours,
                    range: 2...48
                )
                DefrostDurationStepper(
                    title: DefrostMethod.acquaFredda.label,
                    value: $storage.haccp.defrostColdWaterRecommendedHours,
                    range: 1...12
                )
                DefrostDurationStepper(
                    title: DefrostMethod.fornoMicroonde.label,
                    value: $storage.haccp.defrostMicrowaveRecommendedHours,
                    range: 1...8
                )
                DefrostDurationStepper(
                    title: DefrostMethod.altro.label,
                    value: $storage.haccp.defrostOtherRecommendedHours,
                    range: 6...72
                )
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
            .onChange(of: storage.haccp.defrostFridgeRecommendedHours) { storage.saveAll() }
            .onChange(of: storage.haccp.defrostControlledTempRecommendedHours) { storage.saveAll() }
            .onChange(of: storage.haccp.defrostColdWaterRecommendedHours) { storage.saveAll() }
            .onChange(of: storage.haccp.defrostMicrowaveRecommendedHours) { storage.saveAll() }
            .onChange(of: storage.haccp.defrostOtherRecommendedHours) { storage.saveAll() }

            VStack(alignment: .leading, spacing: 20) {
                Text("Operatività")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                
                Stepper(value: $storage.haccp.productExpiryThreshold, in: 1...15) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundStyle(ThemeManager.shared.colorWarning)
                        Text("Soglia Scadenza: \(storage.haccp.productExpiryThreshold) giorni")
                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    }
                }

                Toggle("Codice lotto obbligatorio in tracciabilità", isOn: $storage.haccp.lotEntryMandatory)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                
                Stepper(value: $storage.haccp.storageDurationYears, in: 1...10) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.blue)
                        Text("Conservazione Dati: \(storage.haccp.storageDurationYears) anni")
                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    }
                }
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 20) {
                Text("Lettura lotti (Groq AI)")
                    .font(.headline)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)

                Text("Chiave API Groq per leggere lotto e scadenza dalle foto etichetta (solo Groq AI — Llama 4 Maverick, immagine 768px). Crea la chiave su console.groq.com.")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)

                SecureField("Chiave API Groq", text: Binding(
                    get: { storage.haccp.groqApiKey ?? "" },
                    set: { storage.haccp.groqApiKey = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
            .onChange(of: storage.haccp.fridgeMinTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.fridgeMaxTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.freezerMinTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.freezerMaxTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.blastChillerTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.tempCheckFrequency) { storage.saveAll() }
            .onChange(of: storage.haccp.warningThreshold) { storage.saveAll() }
            .onChange(of: storage.haccp.productExpiryThreshold) { storage.saveAll() }
            .onChange(of: storage.haccp.lotEntryMandatory) { storage.saveAll() }
            .onChange(of: storage.haccp.storageDurationYears) { storage.saveAll() }
            .onChange(of: storage.haccp.oilPolarAttentionLimit) { storage.saveAll() }
            .onChange(of: storage.haccp.oilPolarMaximumLimit) { storage.saveAll() }
            .onChange(of: storage.haccp.oilNonCompliancePhotoRequired) { storage.saveAll() }
            .onChange(of: storage.haccp.groqApiKey) { storage.saveAll() }
        }
    }
}

struct DefrostDurationStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Image(systemName: "snowflake")
                    .foregroundStyle(ThemeManager.shared.colorPrimary)
                Text("\(title): \(value) h")
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            }
        }
    }
}

struct TempConfigBox: View {
    let title: String
    @Binding var value: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            
            HStack {
                TextField("", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                Text(unit)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
            .padding()
            .background(ThemeManager.shared.colorSurfaceElevated)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }
}
