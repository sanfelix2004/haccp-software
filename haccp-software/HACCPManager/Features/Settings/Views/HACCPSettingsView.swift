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
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    TempConfigBox(title: "Frigo (Max)", value: $storage.haccp.fridgeMaxTemp, unit: "°C")
                    TempConfigBox(title: "Freezer (Min)", value: $storage.haccp.freezerMinTemp, unit: "°C")
                }
                
                HStack(spacing: 20) {
                    TempConfigBox(title: "Abbattitore", value: $storage.haccp.blastChillerTemp, unit: "°C")
                    TempConfigBox(title: "Frequenza", value: Binding(get: { Double(storage.haccp.tempCheckFrequency) }, set: { storage.haccp.tempCheckFrequency = Int($0) }), unit: "h")
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Operatività")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Stepper(value: $storage.haccp.productExpiryThreshold, in: 1...15) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("Soglia Scadenza: \(storage.haccp.productExpiryThreshold) giorni")
                            .foregroundColor(.white)
                    }
                }
                
                Stepper(value: $storage.haccp.storageDurationYears, in: 1...10) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.blue)
                        Text("Conservazione Dati: \(storage.haccp.storageDurationYears) anni")
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .onChange(of: storage.haccp.fridgeMaxTemp) { storage.saveAll() }
            .onChange(of: storage.haccp.productExpiryThreshold) { storage.saveAll() }
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
                .foregroundColor(.gray)
            
            HStack {
                TextField("", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(unit)
                    .foregroundColor(.red)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }
}
