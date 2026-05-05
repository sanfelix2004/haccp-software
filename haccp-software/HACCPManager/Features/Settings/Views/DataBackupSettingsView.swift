import SwiftUI
import SwiftData

struct DataBackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var documentItems: [DocumentItem]

    @ObservedObject private var iCloudSync = ICloudDocumentSyncService.shared

    @AppStorage(DocumentsUserSettings.iCloudPDFSyncEnabledKey) private var iCloudPDFSyncEnabled = false

    @State private var showResetConfirm = false
    @State private var showAuthForReset = false
    
    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }
    
    private var isMaster: Bool {
        currentUser?.role == .master
    }

    private var pdfSyncedCount: Int {
        documentItems.filter { $0.format == .pdf && $0.localFilePresent && $0.isSyncedToICloud }.count
    }

    private var pdfPendingICloudCount: Int {
        guard iCloudPDFSyncEnabled else { return 0 }
        return documentItems.filter { $0.format == .pdf && $0.localFilePresent && !$0.isSyncedToICloud }.count
    }

    private var pendingLine: String {
        let base = "PDF copiati su iCloud: \(pdfSyncedCount)"
        if iCloudPDFSyncEnabled {
            return "\(base) · in coda di copia: \(pdfPendingICloudCount)"
        }
        return "\(base) · attiva «Copia automatica…» per vedere la coda e copiare i PDF mancanti."
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

                if isMaster {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: iCloudSync.isUbiquityContainerAvailable ? "icloud.and.arrow.up.fill" : "icloud.slash")
                                .font(.title)
                                .foregroundColor(iCloudSync.isUbiquityContainerAvailable ? .green : .orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(iCloudSync.isUbiquityContainerAvailable ? "iCloud: collegato" : "iCloud: non collegato")
                                    .font(.headline)
                                    .foregroundColor(iCloudSync.isUbiquityContainerAvailable ? .green : .orange)
                                Text(pendingLine)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer(minLength: 0)
                        }

                        Text(iCloudSync.connectionExplanation)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        if let d = iCloudSync.lastSyncActivityDate, !iCloudSync.lastSyncActivity.isEmpty {
                            Text("Ultima operazione (\(d.formatted(date: .omitted, time: .shortened))): \(iCloudSync.lastSyncActivity)")
                                .font(.caption2)
                                .foregroundColor(.cyan.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            iCloudSync.refreshConnectionDiagnostics()
                        } label: {
                            Label("Aggiorna stato connessione", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)

                        Text("I dati operativi restano sul dispositivo (SwiftData). Solo i PDF in Documenti vengono copiati nel container iCloud.")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Toggle(isOn: $iCloudPDFSyncEnabled) {
                            Text("Copia automatica dei PDF su iCloud dopo la generazione")
                                .font(.subheadline)
                        }
                        .disabled(!iCloudSync.isUbiquityContainerAvailable)
                    }
                    .padding(.vertical, 8)
                    .onAppear {
                        iCloudSync.refreshConnectionDiagnostics()
                    }
                    .onChange(of: iCloudPDFSyncEnabled) { _, enabled in
                        guard enabled, isMaster else { return }
                        Task { @MainActor in
                            await iCloudSync.syncAllPendingDocuments(
                                items: documentItems,
                                modelContext: modelContext
                            )
                        }
                    }
                }

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
