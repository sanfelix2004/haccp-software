import SwiftUI

struct LabelPrinterSettingsView: View {
    var storage = SettingsStorageService.shared
    
    var body: some View {
        @Bindable var storage = storage
        VStack(spacing: 32) {
            
            // Empty State for Printers
            VStack(spacing: 24) {
                Image(systemName: "printer.dotmatrix.filled.and.paper.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("Nessuna stampante configurata")
                        .font(.headline)
                    Text("Connetti una stampante termica Bluetooth o Wi-Fi per stampare le etichette di tracciabilità.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button(action: {}) {
                    Text("Cerca stampanti...")
                        .fontWeight(.bold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.02))
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
                .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .onChange(of: storage.printer.showProductName) { storage.saveAll() }
        }
    }
}
