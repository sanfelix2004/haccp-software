import SwiftUI
import SwiftData

struct DataBackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    
    @State private var showResetConfirm = false
    @State private var showAuthForReset = false
    
    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }
    
    private var isMaster: Bool {
        currentUser?.role == .master
    }
    
    var body: some View {
        VStack(spacing: 32) {
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Stato Archiviazione")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Database Locale")
                            .font(.subheadline)
                        Text("SwiftData Encrypted Storage")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("1.2 MB")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Ultimo Backup")
                        .font(.subheadline)
                    Spacer()
                    Text("Mai")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Operazioni Avanzate")
                    .font(.headline)
                
                SettingsActionButton(title: "Esporta Dati (CSV/PDF)", icon: "square.and.arrow.up", isFuture: true)
                SettingsActionButton(title: "Configura Backup iCloud", icon: "icloud.and.arrow.up", isFuture: true)
                
                if isMaster {
                    Divider().background(Color.white.opacity(0.1))
                    
                    Button(action: { showResetConfirm = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Reset completo app")
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .confirmationDialog("Reset Totale", isPresented: $showResetConfirm) {
            Button("CANCELLA TUTTO", role: .destructive) {
                showAuthForReset = true
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Questa azione cancellerà tutti gli utenti, ristoranti, impostazioni e dati locali. Non può essere annullata.")
        }
        .fullScreenCover(isPresented: $showAuthForReset) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .resetDatabase,
                    onAuthorized: {
                        showAuthForReset = false
                        performFullReset()
                    },
                    onCancel: {
                        showAuthForReset = false
                    }
                ) { EmptyView() }
            }
        }
    }
    
    private func performFullReset() {
        appState.factoryReset(modelContext: modelContext)
    }
}

struct SettingsActionButton: View {
    let title: String
    let icon: String
    var isFuture: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
            Text(title)
            Spacer()
            if isFuture {
                Text("PRESTO")
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .foregroundColor(isFuture ? .gray : .white)
    }
}
