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
                    TempConfigBox(title: "Frigo (Max)", value: $storage.haccp.fridgeMaxTemp, unit: "°C")
                    TempConfigBox(title: "Freezer (Min)", value: $storage.haccp.freezerMinTemp, unit: "°C")
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
            .onChange(of: storage.haccp.fridgeMaxTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.freezerMinTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.blastChillerTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.tempCheckFrequency) { storage.saveAll() }
            .onChange(of: storage.haccp.warningThreshold) { storage.saveAll() }
            .onChange(of: storage.haccp.productExpiryThreshold) { storage.saveAll() }
            .onChange(of: storage.haccp.storageDurationYears) { storage.saveAll() }
            .onChange(of: storage.haccp.oilPolarAttentionLimit) { storage.saveAll() }
            .onChange(of: storage.haccp.oilPolarMaximumLimit) { storage.saveAll() }
            .onChange(of: storage.haccp.oilNonCompliancePhotoRequired) { storage.saveAll() }
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
                    .foregroundColor(.red)
            }
            .padding()
            .background(ThemeManager.shared.colorSurfaceElevated)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }
}
