import SwiftUI

struct LabelPrinterSettingsView: View {
    var storage = SettingsStorageService.shared
    
    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: 32) {
            
            // Empty State for Printers
            VStack(spacing: 24) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("Nessuna stampante configurata")
                        .font(.headline)
                    Text("Connetti una stampante termica Bluetooth o Wi-Fi per stampare le etichette di tracciabilità.")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button(action: {}) {
                    Text("Cerca stampanti...")
                        .fontWeight(.bold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(ThemeManager.shared.colorDivider)
                        .cornerRadius(10)
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(20)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Campi Etichetta Standard")
                    .font(.headline)
                
                Group {
                    Toggle("Nome Prodotto", isOn: $storage.printer.showProductName)
                    Toggle("Data Preparazione", isOn: $storage.printer.showPrepDate)
                    Toggle("Data Scadenza", isOn: $storage.printer.showExpiryDate)
                    Toggle("Lotto Produzione", isOn: $storage.printer.showLotNumber)
                    Toggle("Nome Operatore", isOn: $storage.printer.showOperatorName)
                    Toggle("Avvisi Allergeni", isOn: $storage.printer.showAllergenWarning)
                }
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
            .onChange(of: storage.printer.showProductName) { storage.saveAll() }
        }
    }
}
