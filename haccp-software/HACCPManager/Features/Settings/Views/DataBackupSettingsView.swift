//
//  DataBackupSettingsView.swift
//  Uso memoria reale, archiviazione e operazioni dati.
//

import SwiftUI
import SwiftData

struct DataBackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var documentItems: [DocumentItem]

    @ObservedObject private var iCloudSync = ICloudDocumentSyncService.shared

    @AppStorage(DocumentsUserSettings.iCloudPDFSyncEnabledKey) private var iCloudPDFSyncEnabled = false

    @State private var usage = AppStorageUsageBreakdown.empty
    @State private var isCalculatingUsage = false
    @State private var showResetConfirm = false
    @State private var showAuthForReset = false
    @State private var archiveMessage: String?
    @State private var isArchiving = false

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

    private var lastArchiveText: String {
        guard let rid = appState.activeRestaurantId else { return "Nessun ristorante attivo" }
        let key = "DataArchiveService.lastRun.\(rid.uuidString)"
        guard let date = UserDefaults.standard.object(forKey: key) as? Date else {
            return "Mai eseguita"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(spacing: theme.spacing.sectionSpacing) {
            storageUsageCard
            archiveCard
            if isMaster {
                advancedCard
            }
        }
        .task { await refreshUsage() }
        .confirmationDialog("Reset totale", isPresented: $showResetConfirm) {
            Button("Cancella tutto", role: .destructive) {
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
                    onCancel: { showAuthForReset = false }
                ) { EmptyView() }
            }
        }
    }

    private var storageUsageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Spazio occupato")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Spacer()
                Button {
                    Task { await refreshUsage() }
                } label: {
                    if isCalculatingUsage {
                        ProgressView()
                    } else {
                        Label("Aggiorna", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .tint(theme.colorPrimary)
                .disabled(isCalculatingUsage)
            }

            usageRow(
                title: "Database HACCP (SwiftData)",
                subtitle: "Registrazioni, impostazioni, storico operativo",
                bytes: usage.swiftDataBytes,
                icon: "cylinder.split.1x2.fill"
            )
            usageRow(
                title: "PDF e allegati",
                subtitle: "File in Application Support",
                bytes: usage.attachmentsBytes,
                icon: "doc.fill"
            )
            usageRow(
                title: "Cache app",
                subtitle: "File temporanei di sistema",
                bytes: usage.cacheBytes,
                icon: "internaldrive"
            )

            Divider().background(theme.colorDivider)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Totale stimato")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text("Solo su questo iPad")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer()
                Text(AppStorageUsageService.formattedBytes(usage.totalBytes))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.colorPrimary)
            }

            HStack {
                Text("Ultima archiviazione automatica")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Spacer()
                Text(lastArchiveText)
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .padding(16)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    private func usageRow(title: String, subtitle: String, bytes: Int64, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(theme.colorInfo)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer()
            Text(AppStorageUsageService.formattedBytes(bytes))
                .font(theme.typography.headline.monospacedDigit())
                .foregroundStyle(theme.colorTextPrimary)
        }
    }

    private var archiveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Archiviazione dati")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            Text("I record più vecchi di \(PerformanceConfig.activeDataRetentionMonths) mesi vengono contrassegnati come archiviati per alleggerire le schermate operative. I dati restano sul dispositivo.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)

            if let archiveMessage {
                Text(archiveMessage)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorSuccess)
            }

            Button {
                Task { await runManualArchive() }
            } label: {
                Label(isArchiving ? "Archiviazione…" : "Esegui archiviazione ora", systemImage: "archivebox.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.colorPrimary)
            .disabled(isArchiving || appState.activeRestaurantId == nil)
        }
        .padding(16)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Operazioni avanzate (MASTER)")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            iCloudSection

            Divider().background(theme.colorDivider)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset completo app", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    @ViewBuilder
    private var iCloudSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iCloudSync.isUbiquityContainerAvailable ? "icloud.fill" : "icloud.slash")
                    .font(.title2)
                    .foregroundStyle(iCloudSync.isUbiquityContainerAvailable ? theme.colorSuccess : theme.colorWarning)
                VStack(alignment: .leading, spacing: 4) {
                    Text(iCloudSync.isUbiquityContainerAvailable ? "iCloud collegato" : "iCloud non disponibile")
                        .font(theme.typography.subheadline.weight(.semibold))
                    Text("PDF copiati: \(pdfSyncedCount) · in coda: \(pdfPendingICloudCount)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer(minLength: 0)
            }

            Text(iCloudSync.connectionExplanation)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)

            Button("Aggiorna stato iCloud") {
                iCloudSync.refreshConnectionDiagnostics()
            }
            .buttonStyle(.bordered)
            .tint(.cyan)

            Toggle(isOn: $iCloudPDFSyncEnabled) {
                Text("Copia automatica PDF su iCloud")
                    .font(theme.typography.subheadline)
            }
            .disabled(!iCloudSync.isUbiquityContainerAvailable)
        }
        .onAppear { iCloudSync.refreshConnectionDiagnostics() }
        .onChange(of: iCloudPDFSyncEnabled) { _, enabled in
            guard enabled else { return }
            Task { @MainActor in
                await iCloudSync.syncAllPendingDocuments(items: documentItems, modelContext: modelContext)
            }
        }
    }

    private func refreshUsage() async {
        isCalculatingUsage = true
        usage = await AppStorageUsageService.calculate()
        isCalculatingUsage = false
    }

    private func runManualArchive() async {
        guard let rid = appState.activeRestaurantId else { return }
        isArchiving = true
        archiveMessage = nil
        let count = await Task { @MainActor in
            DataArchiveService.archiveRestaurant(context: modelContext, restaurantId: rid)
        }.value
        if count > 0 {
            try? modelContext.save()
            UserDefaults.standard.set(Date(), forKey: "DataArchiveService.lastRun.\(rid.uuidString)")
            archiveMessage = "Archiviati \(count) record."
        } else {
            archiveMessage = "Nessun record da archiviare oltre la soglia."
        }
        isArchiving = false
        await refreshUsage()
    }

    private func performFullReset() {
        appState.factoryReset(modelContext: modelContext)
        Task { await refreshUsage() }
    }
}
