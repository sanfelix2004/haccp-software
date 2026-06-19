import SwiftUI
import SwiftData
import QuickLook
import UIKit

struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var folders: [DocumentFolder]
    @Query private var items: [DocumentItem]
    @Query private var receipts: [GoodsReceipt]
    @Query private var traceabilityRecords: [TraceabilityRecord]
    @Query private var traceabilityImages: [ProductImage]
    @Query private var productions: [Production]
    @Query private var traceabilityLinks: [TraceabilityLink]
    @Query private var traceabilityLogs: [TraceabilityLog]
    @Query private var checklistAuditLogs: [ChecklistAuditLog]
    @Query private var temperatureAuditLogs: [TemperatureAuditLog]
    @StateObject private var vm = DocumentsViewModel()
    @ObservedObject private var iCloudSync = ICloudDocumentSyncService.shared
    @State private var isSyncingICloud = false
    @State private var documentPreviewItem: DocumentPreviewSheetItem?
    @State private var shareURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var pendingDelete: DocumentItem?
    @State private var pendingRegenerate: DocumentItem?
    @State private var showMasterAuthDelete = false
    @State private var showMasterAuthRegenerate = false
    @State private var regenerateError: String?
    @State private var isRefreshingArchive = false
    @State private var folderMetricsById: [UUID: FolderListMetrics] = [:]

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var activeRestaurant: Restaurant? {
        guard let rid = appState.activeRestaurantId else { return nil }
        return restaurants.first(where: { $0.id == rid })
    }

    private var scopedFolders: [DocumentFolder] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return folders
            .filter { $0.restaurantId == rid }
            .sorted { lhs, rhs in
                if lhs.orderIndex == rhs.orderIndex { return lhs.name < rhs.name }
                return lhs.orderIndex < rhs.orderIndex
            }
    }

    private var scopedItems: [DocumentItem] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return items.filter { $0.restaurantId == rid }
    }

    private var scopedReceipts: [GoodsReceipt] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return receipts.filter { $0.restaurantId == rid }
    }

    private var scopedTraceability: [TraceabilityRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return traceabilityRecords.filter { $0.restaurantId == rid }
    }

    private var currentFolder: DocumentFolder? {
        guard let id = vm.selectedFolderId else { return nil }
        return scopedFolders.first(where: { $0.id == id })
    }

    private var venueFolderName: String? {
        activeRestaurant.map { DocumentArchiveLayout.venueFolderName(for: $0) }
    }

    private var rootFolders: [DocumentFolder] {
        guard let venueFolderName else { return [] }
        return scopedFolders.filter {
            $0.parentId == nil && $0.type != .archive && $0.name == venueFolderName
        }
    }

    private var childFolders: [DocumentFolder] {
        guard let currentFolder else { return [] }
        return scopedFolders.filter {
            $0.parentId == currentFolder.id
                && $0.type != .archive
                && !DocumentArchiveLayout.isRetiredFolderTitle($0.name)
        }
    }

    private var visibleItems: [DocumentItem] {
        guard let currentFolder else { return [] }
        return scopedItems
            .filter { $0.folderId == currentFolder.id }
            .sorted { $0.generatedAt > $1.generatedAt }
    }

    private var permissions: UserPermissions { currentUser.permissions }
    private var canManageDocuments: Bool { permissions.can(.manageDocuments) }

    private var syncedPdfCount: Int {
        scopedItems.filter { $0.localFilePresent && $0.format == .pdf && $0.isSyncedToICloud }.count
    }

    private var pendingPdfCount: Int {
        scopedItems.filter { $0.localFilePresent && $0.format == .pdf && !$0.isSyncedToICloud }.count
    }

    private var totalPdfCount: Int {
        scopedItems.filter { $0.format == .pdf && $0.localFilePresent }.count
    }

    private var iCloudSyncEnabled: Bool {
        DocumentsUserSettings.isICloudPDFSyncEnabled
    }

    private var lastMonthlyICloudSyncText: String {
        guard let rid = appState.activeRestaurantId,
              let date = DocumentsUserSettings.lastMonthlyICloudSync(restaurantId: rid) else {
            return "Mai eseguito"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var iCloudContactEmail: String {
        guard let restaurant = activeRestaurant else { return "" }
        return DocumentsUserSettings.iCloudContactEmail(
            restaurantId: restaurant.id,
            restaurantEmailFallback: restaurant.email
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                ModuleScreenHeader(
                    title: "Documenti",
                    subtitle: activeRestaurant.map {
                        "Archivio HACCP di \($0.name) — Singoli e Combinati mensili."
                    } ?? "Archivio PDF mensili HACCP.",
                    systemImage: "doc.text.fill",
                    help: ModuleHelpLibrary.sidebar(.documents)
                )

                if isRefreshingArchive {
                    HStack(spacing: theme.spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Aggiornamento archivio…")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    .padding(.horizontal, theme.spacing.sm)
                    .padding(.vertical, theme.spacing.xs)
                    .background(theme.colorSurfaceElevated.opacity(0.7))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if scopedFolders.isEmpty && currentFolder == nil {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna cartella disponibile",
                        message: "Le cartelle dell'archivio verranno create automaticamente.",
                        actionTitle: nil
                    ))
                } else {
                    if currentFolder != nil {
                        folderNavigationBar
                    }

                    if currentFolder == nil {
                        archiveOverviewSection
                        if let restaurant = activeRestaurant {
                            ICloudArchiveStatusCard(
                                restaurantName: restaurant.name,
                                syncedCount: syncedPdfCount,
                                pendingCount: pendingPdfCount,
                                totalPdfCount: totalPdfCount,
                                isICloudAvailable: iCloudSync.isUbiquityContainerAvailable,
                                isSyncEnabled: iCloudSyncEnabled,
                                lastMonthlySyncText: lastMonthlyICloudSyncText,
                                lastActivity: iCloudSync.lastSyncActivity,
                                contactEmail: iCloudContactEmail,
                                isSyncing: isSyncingICloud,
                                onSyncNow: { syncICloudNow() }
                            )
                            .onAppear { iCloudSync.refreshConnectionDiagnostics() }
                        }
                        folderGrid(folders: rootFolders)
                    } else {
                        if !childFolders.isEmpty {
                            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                                sectionHeader("Sottocartelle", icon: "folder.fill")
                                folderGrid(folders: childFolders)
                            }
                        }

                        VStack(alignment: .leading, spacing: theme.spacing.sm) {
                            sectionHeader("Registri generati", icon: "doc.text.fill")

                            if visibleItems.isEmpty {
                                DashboardEmptyStateView(state: .init(
                                    title: "Nessun documento",
                                    message: "I registri vengono generati automaticamente dai dati HACCP.",
                                    actionTitle: nil
                                ))
                            } else {
                                VStack(spacing: theme.spacing.md) {
                                    ForEach(visibleItems) { doc in
                                        documentRow(doc)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
        .animation(theme.spring, value: isRefreshingArchive)
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Documenti")
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                DocumentArchivePurgeService.consumeMarkerAndPurgeIfNeeded(modelContext: modelContext)
                refreshArchiveLight()
            }
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            refreshArchiveLight()
        }
        .onChange(of: scopedItems.count) { _, _ in
            rebuildFolderMetrics()
        }
        .sheet(item: $documentPreviewItem) { item in
            QuickLookPreviewRepresentable(url: item.url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { shareURLs = [] }) {
            ActivityShareSheet(activityItems: shareURLs)
                .presentationDetents([.medium, .large])
        }
        .alert("Errore rigenerazione", isPresented: Binding(
            get: { regenerateError != nil },
            set: { if !$0 { regenerateError = nil } }
        )) {
            Button("OK", role: .cancel) { regenerateError = nil }
        } message: {
            Text(regenerateError ?? "")
        }
        .fullScreenCover(isPresented: $showMasterAuthDelete) {
            masterAuthDeleteContent
        }
        .fullScreenCover(isPresented: $showMasterAuthRegenerate) {
            masterAuthRegenerateContent
        }
    }

    private var archiveOverviewSection: some View {
        HStack(spacing: theme.spacing.md) {
            Label("\(totalPdfCount) PDF", systemImage: "doc.richtext.fill")
            Label("\(rootFolders.isEmpty ? 0 : descendantFolderIds(for: rootFolders[0].id).count) cartelle", systemImage: "folder.fill")
        }
        .font(theme.typography.caption.weight(.semibold))
        .foregroundStyle(theme.colorTextSecondary)
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorSurfaceElevated.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    private var folderNavigationBar: some View {
        HStack(spacing: theme.spacing.sm) {
            Button {
                withAnimation(theme.spring) {
                    if let current = currentFolder, let parent = current.parentId {
                        vm.selectedFolderId = parent
                    } else {
                        vm.selectedFolderId = nil
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(theme.colorSurfaceElevated.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(PremiumPressButtonStyle(scale: 0.94))
            .accessibilityLabel("Indietro")

            VStack(alignment: .leading, spacing: 2) {
                Text("Cartella")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
                Text(currentFolder?.name ?? "Documenti")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacing.sm)
        .background(theme.colorSurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    @ViewBuilder
    private var masterAuthDeleteContent: some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .deleteDocument,
                onAuthorized: {
                    showMasterAuthDelete = false
                    if let doc = pendingDelete {
                        performDelete(doc)
                        pendingDelete = nil
                    }
                },
                onCancel: {
                    showMasterAuthDelete = false
                    pendingDelete = nil
                }
            ) { EmptyView() }
        } else {
            ThemeManager.shared.colorBackground.ignoresSafeArea().onAppear { showMasterAuthDelete = false }
        }
    }

    @ViewBuilder
    private var masterAuthRegenerateContent: some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .regenerateDocument,
                onAuthorized: {
                    showMasterAuthRegenerate = false
                    if let doc = pendingRegenerate {
                        performRegenerate(doc)
                        pendingRegenerate = nil
                    }
                },
                onCancel: {
                    showMasterAuthRegenerate = false
                    pendingRegenerate = nil
                }
            ) { EmptyView() }
        } else {
            ThemeManager.shared.colorBackground.ignoresSafeArea().onAppear { showMasterAuthRegenerate = false }
        }
    }

    private func syncICloudNow() {
        guard let restaurant = activeRestaurant, !isSyncingICloud else { return }
        isSyncingICloud = true
        Task { @MainActor in
            iCloudSync.refreshConnectionDiagnostics()
            await iCloudSync.syncMonthlyArchive(
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                items: scopedItems,
                modelContext: modelContext,
                monthBoundaryCrossed: false
            )
            isSyncingICloud = false
        }
    }

    /// Sincronizzazione leggera all'apertura: solo cartelle e statistiche (niente generazione PDF).
    private func refreshArchiveLight() {
        guard let restaurant = activeRestaurant, let currentUser else { return }
        if isRefreshingArchive { return }
        isRefreshingArchive = true
        Task { @MainActor in
            await Task.yield()
            vm.service.ensureDefaultFolders(
                restaurantId: restaurant.id,
                restaurantDisplayName: restaurant.name,
                user: currentUser,
                existingFolders: scopedFolders,
                existingItems: scopedItems,
                modelContext: modelContext
            )
            rebuildFolderMetrics()
            if let selected = vm.selectedFolderId, !scopedFolders.contains(where: { $0.id == selected }) {
                vm.selectedFolderId = nil
            }
            isRefreshingArchive = false

            Task(priority: .utility) { @MainActor in
                await DocumentArchivePurgeService.regenerateArchiveIfNeeded(
                    modelContext: modelContext,
                    restaurant: restaurant,
                    user: currentUser
                )
                rebuildFolderMetrics()
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: icon)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colorPrimary)
            Text(title)
                .font(theme.typography.subheadline.bold())
                .foregroundStyle(theme.colorTextPrimary)
        }
    }

    @ViewBuilder
    private func folderGrid(folders: [DocumentFolder]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: theme.spacing.md)], spacing: theme.spacing.md) {
            ForEach(folders) { folder in
                let metrics = folderMetricsById[folder.id] ?? .empty
                DocumentFolderCard(
                    folder: folder,
                    documentCount: metrics.count,
                    latestUpdate: metrics.latest,
                    hasNew: metrics.hasNew
                ) {
                    vm.selectedFolderId = folder.id
                }
            }
        }
    }

    @ViewBuilder
    private func documentRow(_ doc: DocumentItem) -> some View {
        let fileURL = URL(fileURLWithPath: doc.filePath)
        let pdfExists = doc.localFilePresent
            && FileManager.default.fileExists(atPath: doc.filePath)
            && doc.fileName.lowercased().hasSuffix(".pdf")

        DocumentItemCard(
            document: doc,
            pdfExists: pdfExists,
            canManageDocuments: canManageDocuments,
            onOpen: {
                guard pdfExists else { return }
                documentPreviewItem = DocumentPreviewSheetItem(url: fileURL)
            },
            onShare: {
                shareURLs = [fileURL]
                showShareSheet = true
            },
            onExportCSV: { exportCSV(doc) },
            onExportCopy: { exportTemporaryCopy(doc) },
            onRegenerate: {
                pendingRegenerate = doc
                showMasterAuthRegenerate = true
            },
            onDelete: {
                pendingDelete = doc
                showMasterAuthDelete = true
            }
        )
    }

    private func exportCSV(_ doc: DocumentItem) {
        guard let rid = appState.activeRestaurantId else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "it_IT")
        calendar.timeZone = .current
        guard let csv = HACCPRegisterCSVExporter.csvString(
            for: doc,
            receipts: scopedReceipts,
            traceability: scopedTraceability,
            images: traceabilityImages,
            productions: productions.filter { $0.restaurantId == rid },
            links: traceabilityLinks,
            logs: traceabilityLogs,
            calendar: calendar
        ),
        let data = csv.data(using: .utf8)
        else { return }

        let name = doc.fileName.replacingOccurrences(of: ".pdf", with: ".csv", options: .caseInsensitive)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)_\(name)")
        do {
            try data.write(to: tmp)
            shareURLs = [tmp]
            showShareSheet = true
        } catch { }
    }

    private func exportTemporaryCopy(_ doc: DocumentItem) {
        guard let rid = appState.activeRestaurantId else { return }
        do {
            let url = try DocumentGeneratorService.shared.temporaryExportURL(for: doc, restaurantId: rid)
            doc.isExported = true
            doc.exportedAt = Date()
            doc.status = .esportato
            try? modelContext.save()
            shareURLs = [url]
            showShareSheet = true
        } catch { }
    }

    private func performDelete(_ doc: DocumentItem) {
        if FileManager.default.fileExists(atPath: doc.filePath) {
            try? FileManager.default.removeItem(atPath: doc.filePath)
        }
        doc.localFilePresent = false
        doc.checksumSHA256 = ""
        doc.isSyncedToICloud = false
        try? modelContext.save()
    }

    private func performRegenerate(_ doc: DocumentItem) {
        guard let restaurant = activeRestaurant, let currentUser else { return }
        do {
            try HACCPReportEngine.shared.regenerate(
                document: doc,
                restaurant: restaurant,
                user: currentUser,
                reason: "Rigenerazione manuale autorizzata dal MASTER",
                in: modelContext
            )
        } catch {
            regenerateError = error.localizedDescription
        }
    }

    private func rebuildFolderMetrics() {
        guard !scopedFolders.isEmpty else {
            folderMetricsById = [:]
            return
        }
        let threshold = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        let itemsByFolder = Dictionary(grouping: scopedItems, by: \.folderId)
        var metrics: [UUID: FolderListMetrics] = [:]
        for folder in scopedFolders {
            let ids = descendantFolderIds(for: folder.id)
            let items = ids.flatMap { itemsByFolder[$0] ?? [] }
            metrics[folder.id] = FolderListMetrics(
                count: items.count,
                latest: items.map(\.generatedAt).max(),
                hasNew: items.contains { $0.generatedAt >= threshold }
            )
        }
        folderMetricsById = metrics
    }

    private func descendantFolderIds(for rootId: UUID) -> Set<UUID> {
        var visited: Set<UUID> = [rootId]
        var queue: [UUID] = [rootId]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let children = scopedFolders.filter { $0.parentId == current }.map(\.id)
            for child in children where !visited.contains(child) {
                visited.insert(child)
                queue.append(child)
            }
        }
        return visited
    }
}

private struct FolderListMetrics {
    let count: Int
    let latest: Date?
    let hasNew: Bool

    static let empty = FolderListMetrics(count: 0, latest: nil, hasNew: false)
}

private struct DocumentPreviewSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

private final class QuickLookPreviewItem: NSObject, QLPreviewItem {
    let fileURL: URL
    init(url: URL) { self.fileURL = url }
    var previewItemURL: URL? { fileURL }
    var previewItemTitle: String? { fileURL.lastPathComponent }
}

private struct QuickLookPreviewRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let item: QuickLookPreviewItem

        init(url: URL) {
            self.item = QuickLookPreviewItem(url: url)
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
