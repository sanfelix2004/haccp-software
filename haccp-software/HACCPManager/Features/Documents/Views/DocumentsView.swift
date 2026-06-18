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
    @StateObject private var reportEngine = HACCPReportEngine.shared
    @State private var documentPreviewItem: DocumentPreviewSheetItem?
    @State private var shareURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var pendingDelete: DocumentItem?
    @State private var pendingRegenerate: DocumentItem?
    @State private var showMasterAuthDelete = false
    @State private var showMasterAuthRegenerate = false
    @State private var showMasterAuthArchive = false
    @State private var regenerateError: String?
    @State private var isRefreshingArchive = false
    @State private var isPreparingCloudBackup = false
    @State private var isPurgingArchive = false
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
        return scopedFolders.filter { $0.parentId == currentFolder.id }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                ModuleScreenHeader(
                    title: "Documenti",
                    subtitle: activeRestaurant.map {
                        "Archivio mensile di \($0.name): Singoli (ogni funzione) e Combinati (funzioni affini)."
                    } ?? "Archivio PDF mensili HACCP.",
                    systemImage: "doc.text.fill",
                    help: ModuleHelpLibrary.sidebar(.documents)
                )

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
                        statsRow
                        HACCPReportEngineCard(
                            stats: reportEngine.currentStats,
                            lastRunSummary: reportEngine.lastRunSummary,
                            isRunning: reportEngine.isRunning,
                            onRunNow: { runEngineNow() }
                        )
                        folderGrid(folders: rootFolders)
                        cloudSyncStatusCard
                        if canManageDocuments {
                            masterArchiveToolbar
                        }
                    } else {
                        if !childFolders.isEmpty {
                            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                                Text("Sottocartelle")
                                    .font(theme.typography.subheadline.bold())
                                    .foregroundStyle(theme.colorTextPrimary)
                                folderGrid(folders: childFolders)
                            }
                        }

                        VStack(alignment: .leading, spacing: theme.spacing.sm) {
                            Text("Registri generati")
                                .font(theme.typography.subheadline.bold())
                                .foregroundStyle(theme.colorTextPrimary)

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
        .fullScreenCover(isPresented: $showMasterAuthArchive) {
            masterAuthArchiveContent
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            StatCard(
                title: "PDF in archivio",
                value: "\(totalPdfCount)",
                icon: "doc.richtext.fill"
            )
            StatCard(
                title: "Backup cloud",
                value: "\(syncedPdfCount)",
                subtitle: "\(pendingPdfCount) in attesa",
                icon: "icloud.fill",
                accent: theme.colorInfo
            )
            StatCard(
                title: "Cartelle",
                value: "\(rootFolders.count)",
                icon: "folder.fill",
                accent: theme.colorWarning
            )
        }
    }

    private var folderNavigationBar: some View {
        HStack {
            Button {
                if let current = currentFolder, let parent = current.parentId {
                    vm.selectedFolderId = parent
                } else {
                    vm.selectedFolderId = nil
                }
            } label: {
                Label("Indietro", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .tint(theme.colorPrimary)

            Text(currentFolder?.name ?? "Documenti")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
            Spacer()
        }
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

    @ViewBuilder
    private var masterAuthArchiveContent: some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .exportDocumentArchive,
                onAuthorized: {
                    showMasterAuthArchive = false
                    presentFullArchiveShare()
                },
                onCancel: {
                    showMasterAuthArchive = false
                }
            ) { EmptyView() }
        } else {
            ThemeManager.shared.colorBackground.ignoresSafeArea().onAppear { showMasterAuthArchive = false }
        }
    }

    private var cloudSyncStatusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "icloud")
                        .foregroundStyle(theme.colorInfo)
                    Text("Backup su iCloud Drive")
                        .font(theme.typography.subheadline.bold())
                        .foregroundStyle(theme.colorTextPrimary)
                    Spacer()
                    if isRefreshingArchive {
                        ProgressView()
                            .tint(theme.colorPrimary)
                            .scaleEffect(0.8)
                    }
                }
                Text("\(syncedPdfCount) PDF sincronizzati · \(pendingPdfCount) in attesa")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
    }

    private var masterArchiveToolbar: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Archivio completo")
                .font(theme.typography.subheadline.bold())
                .foregroundStyle(theme.colorTextPrimary)
            Button {
                guard !isPurgingArchive, let restaurant = activeRestaurant, let currentUser else { return }
                isPurgingArchive = true
                Task { @MainActor in
                    await DocumentArchivePurgeService.purgeAndRegenerateArchive(
                        restaurant: restaurant,
                        user: currentUser,
                        modelContext: modelContext
                    )
                    isPurgingArchive = false
                }
            } label: {
                Label(
                    isPurgingArchive ? "Ripulitura in corso..." : "Ripulisci e rigenera archivio PDF",
                    systemImage: "trash.circle"
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(theme.colorWarning)
            .disabled(isPurgingArchive)
            Button {
                guard !isPreparingCloudBackup else { return }
                showMasterAuthArchive = true
            } label: {
                Label(
                    isPreparingCloudBackup ? "Preparazione backup..." : "Backup archivio su iCloud Drive",
                    systemImage: "square.and.arrow.up.on.square"
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(theme.colorPrimary)
            .disabled(isPreparingCloudBackup)
            Text("Solo il MASTER può eliminare, rigenerare ed esportare l'archivio completo.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
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
            HACCPReportEngine.shared.refreshStats(restaurantId: restaurant.id, in: modelContext)
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

    private func runEngineNow() {
        guard let restaurant = activeRestaurant, let currentUser else { return }
        Task { @MainActor in
            await HACCPReportEngine.shared.runFullArchive(
                restaurant: restaurant,
                user: currentUser,
                in: modelContext,
                force: true
            )
            HACCPReportEngine.shared.refreshStats(restaurantId: restaurant.id, in: modelContext)
        }
    }

    @ViewBuilder
    private func folderGrid(folders: [DocumentFolder]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
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
            HACCPReportEngine.shared.refreshStats(restaurantId: restaurant.id, in: modelContext)
        } catch {
            regenerateError = error.localizedDescription
        }
    }

    private func presentFullArchiveShare() {
        guard !isPreparingCloudBackup else { return }
        isPreparingCloudBackup = true
        let itemsSnapshot = scopedItems

        Task {
            do {
                let backupFolder = try await Task.detached(priority: .utility) {
                    try buildBackupFolder(from: itemsSnapshot)
                }.value
                await MainActor.run {
                    shareURLs = [backupFolder]
                    showShareSheet = true
                    isPreparingCloudBackup = false
                }
            } catch {
                await MainActor.run {
                    regenerateError = "Backup non riuscito: \(error.localizedDescription)"
                    isPreparingCloudBackup = false
                }
            }
        }
    }

    private func buildBackupFolder(from items: [DocumentItem]) throws -> URL {
        let fm = FileManager.default
        let availableItems: [DocumentItem] = items.filter { item in
            item.localFilePresent && item.filePath.lowercased().hasSuffix(".pdf") && fm.fileExists(atPath: item.filePath)
        }

        guard !availableItems.isEmpty else {
            throw NSError(domain: "DocumentsBackup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nessun PDF disponibile per il backup."])
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let restaurantName = activeRestaurant?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? activeRestaurant!.name
            : "Ristorante"
        let safeRestaurantName = LocalDocumentStorageService.sanitizeFolderName(restaurantName)
        let backupRoot = fm.temporaryDirectory
            .appendingPathComponent("HACCP_Backup_\(stamp)", isDirectory: true)
            .appendingPathComponent(safeRestaurantName, isDirectory: true)
        if fm.fileExists(atPath: backupRoot.path) {
            try fm.removeItem(at: backupRoot)
        }
        try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        for item in availableItems {
            let sourceURL = URL(fileURLWithPath: item.filePath)
            let destinationDir = backupRoot
                .appendingPathComponent(periodFolderLabel(for: item), isDirectory: true)
                .appendingPathComponent(moduleFolderLabel(for: item), isDirectory: true)
            try fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            let destination = destinationDir.appendingPathComponent(sourceURL.lastPathComponent)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)
        }
        return backupRoot
    }

    private func periodFolderLabel(for item: DocumentItem) -> String {
        "Mensili"
    }

    private func moduleFolderLabel(for item: DocumentItem) -> String {
        let group = DocumentArchiveLayout.groupFolderName(for: item.module)
        let module = DocumentArchiveLayout.moduleFolderTitle(item.module)
        return "\(group)/\(module)"
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
