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
    @Query private var restaurants: [Restaurant]

    @ObservedObject private var iCloudSync = ICloudDocumentSyncService.shared

    @AppStorage(DocumentsUserSettings.iCloudPDFSyncEnabledKey) private var iCloudPDFSyncEnabled = true

    @State private var iCloudContactEmail: String = ""
    @State private var emailValidationMessage: String?
    @State private var isSyncingICloud = false
    @State private var pulseICloud = false

    @State private var usage = AppStorageUsageBreakdown.empty
    @State private var isCalculatingUsage = false
    @State private var showResetConfirm = false
    @State private var showAuthForReset = false
    @State private var archiveMessage: String?
    @State private var isArchiving = false

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var canManageData: Bool {
        currentUser.permissions.can(.manageDataAndBackup)
    }

    private var activeRestaurant: Restaurant? {
        guard let rid = appState.activeRestaurantId else { return nil }
        return restaurants.first { $0.id == rid }
    }

    private var scopedDocumentItems: [DocumentItem] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return documentItems.filter { $0.restaurantId == rid }
    }

    private var pdfTotalCount: Int {
        scopedDocumentItems.filter { $0.format == .pdf && $0.localFilePresent }.count
    }

    private var pdfSyncedCount: Int {
        scopedDocumentItems.filter { $0.format == .pdf && $0.localFilePresent && $0.isSyncedToICloud }.count
    }

    private var pdfPendingICloudCount: Int {
        guard iCloudPDFSyncEnabled else { return 0 }
        return scopedDocumentItems.filter { $0.format == .pdf && $0.localFilePresent && !$0.isSyncedToICloud }.count
    }

    private var iCloudSyncProgress: Double {
        guard pdfTotalCount > 0 else { return isSyncingICloud ? 0.35 : 0 }
        return Double(pdfSyncedCount) / Double(pdfTotalCount)
    }

    private var iCloudAccent: Color {
        if !iCloudPDFSyncEnabled || !iCloudSync.isUbiquityContainerAvailable { return theme.colorWarning }
        if pdfPendingICloudCount > 0 { return theme.colorInfo }
        return theme.colorSuccess
    }

    private var lastMonthlyICloudSyncText: String {
        guard let rid = appState.activeRestaurantId,
              let date = DocumentsUserSettings.lastMonthlyICloudSync(restaurantId: rid) else {
            return "Mai eseguita"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
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
        VStack(spacing: theme.spacing.lg) {
            storageUsageCard
            if canManageData {
                iCloudBackupCard
            }
            archiveCard
            if canManageData {
                dangerZoneCard
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

    // MARK: - Storage

    private var storageUsageCard: some View {
        GlassCard(elevated: true) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text("Spazio occupato")
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextPrimary)
                        Text("Solo su questo dispositivo")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    Spacer()
                    Button {
                        Task { await refreshUsage() }
                    } label: {
                        Group {
                            if isCalculatingUsage {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(theme.colorSurfaceElevated.opacity(0.8))
                        .clipShape(Circle())
                    }
                    .buttonStyle(PremiumPressButtonStyle(scale: 0.94))
                    .disabled(isCalculatingUsage)
                    .accessibilityLabel("Aggiorna uso memoria")
                }

                usageRow(
                    title: "Database HACCP",
                    subtitle: "Registrazioni e impostazioni",
                    bytes: usage.swiftDataBytes,
                    icon: "cylinder.split.1x2.fill",
                    color: theme.colorPrimary
                )
                usageRow(
                    title: "PDF e allegati",
                    subtitle: "Application Support",
                    bytes: usage.attachmentsBytes,
                    icon: "doc.richtext.fill",
                    color: theme.colorInfo
                )
                usageRow(
                    title: "Cache app",
                    subtitle: "File temporanei",
                    bytes: usage.cacheBytes,
                    icon: "internaldrive",
                    color: theme.colorTextSecondary
                )

                Divider().background(theme.colorDivider)

                HStack(alignment: .firstTextBaseline) {
                    Text("Totale stimato")
                        .font(theme.typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colorTextPrimary)
                    Spacer()
                    Text(AppStorageUsageService.formattedBytes(usage.totalBytes))
                        .font(theme.typography.title2.weight(.bold))
                        .foregroundStyle(theme.colorPrimary)
                }

                HStack {
                    Label("Ultima archiviazione automatica", systemImage: "archivebox")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    Spacer()
                    Text(lastArchiveText)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
        }
    }

    private func usageRow(title: String, subtitle: String, bytes: Int64, icon: String, color: Color) -> some View {
        let fraction = usage.totalBytes > 0 ? min(1, Double(bytes) / Double(usage.totalBytes)) : 0

        return VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(spacing: theme.spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(theme.typography.subheadline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text(subtitle)
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer()
                Text(AppStorageUsageService.formattedBytes(bytes))
                    .font(theme.typography.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.colorTextPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.colorSurfaceElevated.opacity(0.9))
                    Capsule()
                        .fill(color.opacity(0.75))
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - iCloud

    private var iCloudBackupCard: some View {
        GlassCard(elevated: true) {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                HStack(alignment: .top, spacing: theme.spacing.md) {
                    ZStack {
                        Circle()
                            .fill(iCloudAccent.opacity(0.14))
                            .frame(width: 52, height: 52)
                        Image(systemName: iCloudSync.isUbiquityContainerAvailable ? "icloud.fill" : "icloud.slash")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(iCloudAccent)
                            .scaleEffect(pulseICloud ? 1.06 : 1)
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text("Backup iCloud Drive")
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextPrimary)
                        if let name = activeRestaurant?.name {
                            Text(name)
                                .font(theme.typography.caption.weight(.semibold))
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                        Text(iCloudStatusTitle)
                            .font(theme.typography.subheadline.weight(.semibold))
                            .foregroundStyle(iCloudAccent)
                        Text("Ultimo backup mensile: \(lastMonthlyICloudSyncText)")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    Spacer(minLength: 0)
                }

                Toggle(isOn: $iCloudPDFSyncEnabled) {
                    Text("Backup automatico mensile")
                        .font(theme.typography.subheadline)
                }
                .tint(theme.colorInfo)
                .disabled(!iCloudSync.isUbiquityContainerAvailable)

                iCloudProgressStrip

                emailFieldSection

                if !iCloudSync.connectionExplanation.isEmpty {
                    Text(iCloudSync.connectionExplanation)
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !iCloudSync.lastSyncActivity.isEmpty, !isSyncingICloud {
                    Label(iCloudSync.lastSyncActivity, systemImage: "clock.arrow.circlepath")
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }

                HStack(spacing: theme.spacing.sm) {
                    SecondaryButton(title: "Stato iCloud", icon: "arrow.clockwise") {
                        iCloudSync.refreshConnectionDiagnostics()
                    }
                    .frame(maxWidth: .infinity)

                    Button {
                        Task { await runManualICloudSync() }
                    } label: {
                        HStack(spacing: theme.spacing.sm) {
                            if isSyncingICloud {
                                ProgressView().tint(theme.colorTextOnPrimary)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                    .font(.headline.weight(.semibold))
                            }
                            Text(isSyncingICloud ? "Sync…" : "Sincronizza")
                                .font(theme.typography.headline)
                        }
                        .foregroundStyle(theme.colorTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: theme.spacing.buttonMinHeight)
                        .background(
                            RoundedRectangle(cornerRadius: theme.spacing.buttonCornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.colorInfo, theme.colorInfo.opacity(0.88)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                    .disabled(isSyncingICloud || !iCloudPDFSyncEnabled || !iCloudSync.isUbiquityContainerAvailable)
                    .opacity(isSyncingICloud || !iCloudPDFSyncEnabled || !iCloudSync.isUbiquityContainerAvailable ? 0.55 : 1)
                    .frame(maxWidth: .infinity)
                }

                Text("A fine mese i PDF vengono copiati su iCloud con la struttura Mensili → {Modulo}.")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .onAppear {
            loadICloudContactEmail()
            iCloudSync.refreshConnectionDiagnostics()
            updateICloudPulse(isSyncingICloud)
        }
        .onChange(of: isSyncingICloud) { _, syncing in
            updateICloudPulse(syncing)
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            loadICloudContactEmail()
        }
        .onChange(of: iCloudContactEmail) { _, newValue in
            persistEmail(newValue)
        }
        .onChange(of: iCloudPDFSyncEnabled) { _, enabled in
            DocumentsUserSettings.isICloudPDFSyncEnabled = enabled
            guard enabled else { return }
            Task { await runManualICloudSync() }
        }
    }

    private var iCloudStatusTitle: String {
        if !iCloudPDFSyncEnabled { return "Backup disattivato" }
        if !iCloudSync.isUbiquityContainerAvailable { return "iCloud non disponibile" }
        if isSyncingICloud { return "Sincronizzazione in corso…" }
        if pdfPendingICloudCount > 0 { return "\(pdfPendingICloudCount) PDF in coda" }
        if pdfTotalCount > 0 { return "Archivio allineato" }
        return "In attesa dei PDF mensili"
    }

    private var iCloudProgressStrip: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack {
                Text("Copertura cloud")
                    .font(theme.typography.caption2.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
                Spacer()
                Text("\(pdfSyncedCount)/\(pdfTotalCount) PDF")
                    .font(theme.typography.caption2.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.colorSurfaceElevated.opacity(0.9))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [iCloudAccent.opacity(0.85), iCloudAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * iCloudSyncProgress))
                        .animation(theme.spring, value: iCloudSyncProgress)
                }
            }
            .frame(height: 8)
        }
    }

    private var emailFieldSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text("Email di riferimento iCloud")
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
            TextField("nome@icloud.com", text: $iCloudContactEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(theme.spacing.sm)
                .background(theme.colorSurfaceElevated.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.spacing.cornerSmall, style: .continuous)
                        .stroke(
                            emailValidationMessage == nil ? theme.colorBorder.opacity(0.5) : theme.colorWarning,
                            lineWidth: 1
                        )
                )
                .disabled(activeRestaurant == nil)
            Text("Usa la stessa email dell'account iCloud del dispositivo.")
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
            if let emailValidationMessage {
                Label(emailValidationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorWarning)
            }
        }
    }

    // MARK: - Archive

    private var archiveCard: some View {
        GlassCard(elevated: true) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                HStack(spacing: theme.spacing.sm) {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(theme.colorPrimary)
                    Text("Archiviazione dati")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                }

                Text("I record più vecchi di \(PerformanceConfig.activeDataRetentionMonths) mesi vengono contrassegnati come archiviati per alleggerire le schermate operative. I dati restano sul dispositivo.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let archiveMessage {
                    Label(archiveMessage, systemImage: "checkmark.circle.fill")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorSuccess)
                }

                PrimaryButton(
                    title: isArchiving ? "Archiviazione…" : "Esegui archiviazione ora",
                    icon: "archivebox.fill",
                    isLoading: isArchiving
                ) {
                    Task { await runManualArchive() }
                }
                .disabled(isArchiving || appState.activeRestaurantId == nil)
                .opacity(appState.activeRestaurantId == nil ? 0.55 : 1)
            }
        }
    }

    // MARK: - Danger zone

    private var dangerZoneCard: some View {
        GlassCard(elevated: false) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Label("Zona pericolosa", systemImage: "exclamationmark.triangle.fill")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorError)

                Text("Il reset completo cancella utenti, ristoranti e tutti i dati locali. Operazione irreversibile.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)

                DangerButton(title: "Reset completo app", icon: "trash.fill") {
                    showResetConfirm = true
                }
            }
        }
    }

    // MARK: - Actions

    private func updateICloudPulse(_ syncing: Bool) {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseICloud = syncing
        }
    }

    private func persistEmail(_ newValue: String) {
        guard let rid = appState.activeRestaurantId else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            emailValidationMessage = nil
            return
        }
        if EmailValidator.isValid(trimmed) {
            DocumentsUserSettings.setICloudContactEmail(trimmed, restaurantId: rid)
            if let restaurant = activeRestaurant {
                restaurant.email = EmailValidator.normalized(trimmed)
                try? modelContext.save()
            }
            emailValidationMessage = nil
        } else {
            emailValidationMessage = "Formato email non valido."
        }
    }

    private func loadICloudContactEmail() {
        guard let restaurant = activeRestaurant else {
            iCloudContactEmail = ""
            return
        }
        iCloudContactEmail = DocumentsUserSettings.iCloudContactEmail(
            restaurantId: restaurant.id,
            restaurantEmailFallback: restaurant.email
        )
    }

    private func runManualICloudSync() async {
        guard let rid = appState.activeRestaurantId else { return }
        isSyncingICloud = true
        iCloudSync.refreshConnectionDiagnostics()
        await iCloudSync.syncMonthlyArchive(
            restaurantId: rid,
            restaurantName: activeRestaurant?.name ?? "Ristorante",
            items: scopedDocumentItems,
            modelContext: modelContext,
            monthBoundaryCrossed: false
        )
        isSyncingICloud = false
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
