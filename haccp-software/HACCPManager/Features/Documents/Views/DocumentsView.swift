import SwiftUI
import SwiftData
import QuickLook
import UIKit

struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
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
    @State private var lastArchiveRefreshAt: Date?
    @State private var lastArchiveRestaurantId: UUID?

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

    private var rootFolders: [DocumentFolder] {
        scopedFolders.filter { $0.parentId == nil && $0.type != .archive }
    }

    private var childFolders: [DocumentFolder] {
        guard let currentFolder else { return [] }
        return scopedFolders.filter { $0.parentId == currentFolder.id }
    }

    private var visibleItems: [DocumentItem] {
        guard let currentFolder else { return [] }
        var base = scopedItems.filter { $0.folderId == currentFolder.id }
        switch vm.selectedPeriodFilter {
        case .all:
            break
        case .giornaliero:
            base = base.filter { $0.type == .giornaliero }
        case .settimanale:
            base = base.filter { $0.type == .settimanale }
        case .mensile:
            base = base.filter { $0.type == .mensile }
        case .annuale:
            base = base.filter { $0.type == .annuale }
        }
        return base.sorted { $0.generatedAt > $1.generatedAt }
    }

    private var isMaster: Bool {
        currentUser?.role == .master
    }

    private var syncedPdfCount: Int {
        scopedItems.filter { $0.localFilePresent && $0.format == .pdf && $0.isSyncedToICloud }.count
    }

    private var pendingPdfCount: Int {
        scopedItems.filter { $0.localFilePresent && $0.format == .pdf && !$0.isSyncedToICloud }.count
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Documenti") {
                if scopedFolders.isEmpty && currentFolder == nil {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna cartella disponibile",
                        message: "Le cartelle dell'archivio verranno create automaticamente.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 14) {
                        if currentFolder != nil {
                            folderNavigationBar
                        }

                        if currentFolder == nil {
                            folderGrid(folders: rootFolders)
                            cloudSyncStatusCard
                            if isMaster {
                                masterArchiveToolbar
                            }
                        } else {
                            if !childFolders.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sottocartelle")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white.opacity(0.9))
                                    folderGrid(folders: childFolders)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Registri generati")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white.opacity(0.9))
                                if visibleItems.isEmpty {
                                    DashboardEmptyStateView(state: .init(
                                        title: "Nessun documento",
                                        message: "I registri vengono generati automaticamente dai dati HACCP.",
                                        actionTitle: nil
                                    ))
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(visibleItems) { doc in
                                            documentRow(doc)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Documenti")
        .onAppear {
            refreshArchive()
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            refreshArchive()
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
            .tint(.white)

            Text(currentFolder?.name ?? "Documenti")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Picker("Periodo", selection: $vm.selectedPeriodFilter) {
                ForEach(DocumentsViewModel.PeriodFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)
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
            Color.black.ignoresSafeArea().onAppear { showMasterAuthDelete = false }
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
            Color.black.ignoresSafeArea().onAppear { showMasterAuthRegenerate = false }
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
            Color.black.ignoresSafeArea().onAppear { showMasterAuthArchive = false }
        }
    }

    private var cloudSyncStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "icloud")
                    .foregroundColor(.cyan)
                Text("Backup cloud (iCloud Drive via File)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.95))
                Spacer()
                if isRefreshingArchive {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
            }
            Text("PDF sincronizzati: \(syncedPdfCount) · in attesa: \(pendingPdfCount)")
                .font(.caption)
                .foregroundColor(.gray)
            Text("Premi «Backup archivio su iCloud Drive» per salvare tutti i PDF direttamente in File/iCloud Drive senza account developer.")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    private var masterArchiveToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Archivio completo")
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.9))
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
            .tint(.white)
            .disabled(isPreparingCloudBackup)
            Text("Solo il MASTER può eliminare, rigenerare ed esportare l'archivio completo. Le copie temporanee in Esporta vengono rimosse dopo 10 giorni.")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.top, 4)
    }

    private func exportSyncSummary(for doc: DocumentItem) -> String {
        let size = ByteCountFormatter.string(fromByteCount: doc.sizeInBytes, countStyle: .file)
        let exported = doc.isExported ? "Esportato: sì" : "Esportato: no"
        let sync: String = {
            if doc.isSyncedToICloud { return "Backup cloud: confermato" }
            return "Backup cloud: locale (da esportare)"
        }()
        let checksum = doc.checksumSHA256.isEmpty ? "Checksum: —" : "Checksum: \(doc.checksumSHA256.prefix(12))…"
        let fileState = doc.localFilePresent ? "File locale: presente" : "File locale: assente (rigenerabile)"
        let gen = doc.generatedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(gen) · \(size) · \(exported) · \(sync) · \(checksum) · \(fileState)"
    }

    private func refreshArchive() {
        guard let restaurant = activeRestaurant, let currentUser else { return }
        if isRefreshingArchive { return }
        if lastArchiveRestaurantId == restaurant.id,
           let last = lastArchiveRefreshAt,
           Date().timeIntervalSince(last) < 120 {
            return
        }
        isRefreshingArchive = true
        lastArchiveRestaurantId = restaurant.id
        Task { @MainActor in
            await Task.yield()
            vm.service.ensureDefaultFolders(
                restaurantId: restaurant.id,
                user: currentUser,
                existingFolders: scopedFolders,
                existingItems: scopedItems,
                modelContext: modelContext
            )
            DocumentGeneratorService.shared.syncArchive(
                restaurant: restaurant,
                user: currentUser,
                receipts: receipts,
                traceabilityRecords: traceabilityRecords,
                traceabilityImages: traceabilityImages,
                productions: productions,
                traceabilityLinks: traceabilityLinks,
                traceabilityLogs: traceabilityLogs,
                checklistAuditLogs: checklistAuditLogs,
                temperatureAuditLogs: temperatureAuditLogs,
                modelContext: modelContext
            )
            if let selected = vm.selectedFolderId, !scopedFolders.contains(where: { $0.id == selected }) {
                vm.selectedFolderId = nil
            }
            lastArchiveRefreshAt = Date()
            isRefreshingArchive = false
        }
    }

    @ViewBuilder
    private func folderGrid(folders: [DocumentFolder]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
            ForEach(folders) { folder in
                let count = countItems(includingChildrenOf: folder)
                let latest = latestUpdate(includingChildrenOf: folder)
                let hasNew = hasNewReports(includingChildrenOf: folder)
                Button {
                    vm.selectedFolderId = folder.id
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            Spacer()
                            if hasNew {
                                Text("NUOVO")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                        }
                        Text(folder.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Text(count == 0 ? "Nessun documento" : "\(count) documenti")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Aggiornata: \(latest?.formatted(date: .abbreviated, time: .shortened) ?? "—")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func documentRow(_ doc: DocumentItem) -> some View {
        let fileURL = URL(fileURLWithPath: doc.filePath)
        let pdfExists = doc.localFilePresent
            && FileManager.default.fileExists(atPath: doc.filePath)
            && doc.fileName.lowercased().hasSuffix(".pdf")

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundColor(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title.isEmpty ? doc.fileName : doc.title)
                    .foregroundColor(.white)
                Text(doc.fileName)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("\(doc.module.label) · \(doc.type.label) · \(doc.format.label)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(exportSyncSummary(for: doc))
                    .font(.caption2)
                    .foregroundColor(.gray)
                if doc.status == .fallito {
                    Text("Generazione fallita — il MASTER può rigenerare.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button("Apri") {
                    guard pdfExists else { return }
                    documentPreviewItem = DocumentPreviewSheetItem(url: fileURL)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(!pdfExists)

                if pdfExists {
                    ShareLink(item: fileURL) {
                        Text("Condividi PDF")
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }

                Button("CSV") {
                    exportCSV(doc)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button("Esporta copia") {
                    exportTemporaryCopy(doc)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                if isMaster {
                    Button("Rigenera") {
                        pendingRegenerate = doc
                        showMasterAuthRegenerate = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)

                    Button("Elimina", role: .destructive) {
                        pendingDelete = doc
                        showMasterAuthDelete = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
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
            try DocumentGeneratorService.shared.regenerateDocument(
                doc,
                restaurant: restaurant,
                user: currentUser,
                folders: folders,
                receipts: receipts,
                traceabilityRecords: traceabilityRecords,
                traceabilityImages: traceabilityImages,
                productions: productions,
                traceabilityLinks: traceabilityLinks,
                traceabilityLogs: traceabilityLogs,
                checklistAuditLogs: checklistAuditLogs,
                temperatureAuditLogs: temperatureAuditLogs,
                allDocumentItems: items,
                modelContext: modelContext
            )
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
        switch item.type {
        case .giornaliero: return "Giornalieri"
        case .settimanale: return "Settimanali"
        case .mensile: return "Mensili"
        case .annuale: return "Annuali"
        case .nonConformita: return "Non conformità"
        default: return "Altri"
        }
    }

    private func moduleFolderLabel(for item: DocumentItem) -> String {
        switch item.module {
        case .ricezioneMerci: return "Ricezione merci"
        case .tracciabilita: return "Tracciabilità"
        case .haccpCombinato: return "HACCP combinato"
        case .nonConformita: return "Registro non conformità"
        default: return item.module.label
        }
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

    private func countItems(includingChildrenOf folder: DocumentFolder) -> Int {
        let ids = descendantFolderIds(for: folder.id)
        return scopedItems.filter { ids.contains($0.folderId) }.count
    }

    private func latestUpdate(includingChildrenOf folder: DocumentFolder) -> Date? {
        let ids = descendantFolderIds(for: folder.id)
        return scopedItems
            .filter { ids.contains($0.folderId) }
            .map(\.generatedAt)
            .max()
    }

    private func hasNewReports(includingChildrenOf folder: DocumentFolder) -> Bool {
        let ids = descendantFolderIds(for: folder.id)
        let threshold = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        return scopedItems.contains { ids.contains($0.folderId) && $0.generatedAt >= threshold }
    }
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
