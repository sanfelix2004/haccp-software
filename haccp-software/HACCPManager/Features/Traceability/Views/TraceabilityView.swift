import SwiftUI
import SwiftData
import AVFoundation
import Combine

struct TraceabilityView: View {
    enum DateFilter: String, CaseIterable, Identifiable {
        case all = "Tutte le date"
        case today = "Oggi"
        case month = "Ultimo mese"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var productionLabels: [ProductionLabelRecord]
    @StateObject private var dataStore = TraceabilityDataStore()

    @State private var selectedTraceabilityForProduction: TraceabilityRecord?
    @State private var showProductionSelection = false
    @State private var pendingProductionIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var selectedStatus: ProductStatus?
    @State private var selectedDateFilter: DateFilter = .all
    @State private var detailRecord: TraceabilityRecord?
    @State private var nonComplianceRecord: TraceabilityRecord?
    @State private var nonComplianceNote = ""
    @State private var nonComplianceCorrectiveAction = ""
    @State private var nonCompliancePhotoData: Data?
    @State private var ncAwaitingCapture = false
    @StateObject private var ncCamera = FinalizeReceiptCameraViewModel()
    @State private var showMasterAuthDelete = false
    @State private var recordPendingDelete: TraceabilityRecord?
    @State private var withdrawRecord: TraceabilityRecord?
    @State private var errorMessage: String?
    @State private var labelDraft: ProductionLabelDraft?

    private let productionLibraryService = ProductionLibraryService()
    private let expiryService = TraceabilityExpiryService()
    private let service = TraceabilityService()
    private let labelService = ProductionLabelsService()

    private func makeContext() -> TraceabilityContext {
        TraceabilityContext(store: dataStore)
    }

    private func filteredRecords(using context: TraceabilityContext) -> [TraceabilityRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return dataStore.records.filter { record in
            let searchOk = query.isEmpty || context.matchesSearch(record, query: query)
            let statusOk = selectedStatus == nil || record.productStatus == selectedStatus
            let dateOk: Bool = {
                switch selectedDateFilter {
                case .all: return true
                case .today: return Calendar.current.isDateInToday(record.createdAt)
                case .month:
                    return record.createdAt >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
                }
            }()
            return searchOk && statusOk && dateOk
        }
    }

    private func stats(using context: TraceabilityContext) -> (total: Int, available: Int, expiring: Int, issues: Int) {
        let thresholdDays = SettingsStorageService.shared.haccp.productExpiryThreshold
        let soon = Calendar.current.date(byAdding: .day, value: thresholdDays, to: Date()) ?? Date()
        var available = 0
        var expiring = 0
        var issues = 0
        for record in dataStore.records {
            if record.isNonCompliant || record.productStatus == .rejected || record.productStatus == .expired {
                issues += 1
            }
            if record.productStatus == .available || record.productStatus == .partiallyUsed {
                available += 1
                if let expiry = context.expiryDate(for: record), expiry <= soon, expiry >= Date() {
                    expiring += 1
                }
            }
        }
        return (dataStore.records.count, available, expiring, issues)
    }

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var activeRestaurant: Restaurant? {
        guard let rid = appState.activeRestaurantId else { return nil }
        return restaurants.first { $0.id == rid }
    }

    private var scopedLabels: [ProductionLabelRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return productionLabels.filter { $0.restaurantId == rid }
    }

    private var permissions: UserPermissions { currentUser.permissions }
    private var canDeleteRecords: Bool { permissions.can(.deleteTraceabilityRecords) }

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                emptyRestaurant
            } else if dataStore.isLoading && dataStore.records.isEmpty {
                ProgressView("Caricamento tracciabilità…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Tracciabilità")
        .haccpControlTint()
        .task(id: appState.activeRestaurantId) {
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
        .onAppear(perform: refreshExpiredStatuses)
        .task(id: appState.activeRestaurantId) {
            refreshExpiredStatuses()
        }
        .alert("Tracciabilità", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showProductionSelection) { productionSelectionSheet }
        .sheet(item: $detailRecord) { record in detailSheet(for: record) }
        .sheet(isPresented: Binding(get: { nonComplianceRecord != nil }, set: { if !$0 { nonComplianceRecord = nil } })) {
            nonComplianceSheet
        }
        .sheet(isPresented: Binding(
            get: { labelDraft != nil },
            set: { if !$0 { labelDraft = nil } }
        )) {
            labelEditorSheet
        }
        .sheet(item: $withdrawRecord) { record in
            if let user = currentUser {
                TraceabilityWithdrawSheet(
                    record: record,
                    user: user,
                    onSaved: {
                        withdrawRecord = nil
                        dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
                    },
                    onCancel: { withdrawRecord = nil }
                )
            }
        }
        .onReceive(ncCamera.$capturedPhotoData) { data in
            guard ncAwaitingCapture, let data, !data.isEmpty else { return }
            ncAwaitingCapture = false
            nonCompliancePhotoData = data
            ncCamera.stop()
        }
        .fullScreenCover(isPresented: $showMasterAuthDelete) { masterDeleteOverlay }
    }

    private var emptyRestaurant: some View {
        DashboardEmptyStateView(state: .init(
            title: "Seleziona un ristorante",
            message: "La tracciabilità è legata al ristorante attivo.",
            actionTitle: nil
        ))
        .padding(theme.spacing.screenPadding)
    }

    private var mainScroll: some View {
        let context = makeContext()
        let metrics = stats(using: context)
        let records = filteredRecords(using: context)

        return ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Tracciabilità",
                    subtitle: "Lotti, fornitori, scadenze e collegamento ai piatti del catalogo",
                    systemImage: "archivebox.fill",
                    help: ModuleHelpLibrary.sidebar(.traceability)
                )

                statsRow(metrics)

                DashboardCardView(title: "Azioni rapide", subtitle: "Aggiungi prodotti dalla ricezione") {
                    PrimaryButton(title: "Ricezione merci", icon: "shippingbox.fill") {
                        appState.navigateToGoodsReceiving = true
                    }
                }

                TraceabilityFilterBar(
                    searchText: $searchText,
                    selectedStatus: $selectedStatus,
                    selectedDateFilter: $selectedDateFilter
                )

                DashboardCardView(
                    title: "Prodotti tracciati",
                    subtitle: "\(records.count) risultati"
                ) {
                    if records.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessun prodotto",
                            message: searchText.isEmpty
                                ? "Ricevi merci per popolare la tracciabilità HACCP."
                                : "Nessun risultato per i filtri attivi. Prova a cambiare ricerca o periodo.",
                            actionTitle: searchText.isEmpty ? "Vai a Ricezione merci" : nil
                        )) {
                            if searchText.isEmpty {
                                appState.navigateToGoodsReceiving = true
                            }
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(records.prefix(100)) { record in
                                TraceabilityRecordCard(
                                    display: context.display(for: record),
                                    image: context.image(for: record)
                                ) {
                                    detailRecord = record
                                }
                            }
                            if records.count > 100 {
                                Text("Mostrati i primi 100 risultati. Affina la ricerca per trovare altro.")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colorTextSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
    }

    private func statsRow(_ metrics: (total: Int, available: Int, expiring: Int, issues: Int)) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(title: "Totale", value: "\(metrics.total)", subtitle: "Prodotti", icon: "archivebox.fill", accent: theme.colorPrimary)
            StatCard(title: "Disponibili", value: "\(metrics.available)", subtitle: "In uso", icon: "checkmark.circle.fill", accent: theme.colorSuccess)
            StatCard(title: "In scadenza", value: "\(metrics.expiring)", subtitle: "Entro \(SettingsStorageService.shared.haccp.productExpiryThreshold) gg", icon: "clock.badge.exclamationmark", accent: metrics.expiring > 0 ? theme.colorWarning : theme.colorTextSecondary)
            StatCard(title: "Criticità", value: "\(metrics.issues)", subtitle: "Da verificare", icon: "exclamationmark.triangle.fill", accent: metrics.issues > 0 ? theme.colorError : theme.colorTextSecondary)
        }
    }

    @ViewBuilder
    private func detailSheet(for record: TraceabilityRecord) -> some View {
        let context = makeContext()
        TraceabilityRecordDetailSheet(
            record: record,
            display: context.display(for: record),
            image: context.image(for: record),
            associatedProductions: context.associatedProductions(for: record),
            defrostRecords: context.defrostRecords(for: record),
            receiptStatus: context.receiptStatusLabel(for: record),
            canDeleteRecords: canDeleteRecords,
            hasExistingLabel: {
                let draft = labelService.draft(from: record)
                return ProductionLabelLinkMatcher.existingLabel(for: draft, in: scopedLabels) != nil
            }(),
            onAssociate: { beginProductionAssociation(record) },
            onLabel: { beginLabel(for: record) },
            onNonCompliant: { beginNonCompliance(record) },
            onWithdraw: { withdrawRecord = record },
            onDelete: {
                recordPendingDelete = record
                showMasterAuthDelete = true
            },
            onDismiss: { detailRecord = nil }
        )
    }

    private var productionSelectionSheet: some View {
        ProductionSelectionView(
            initialSelectedIds: pendingProductionIds,
            onCancel: { showProductionSelection = false },
            onConfirm: { selectedProductions in
                guard let record = selectedTraceabilityForProduction else { return }
                do {
                    try productionLibraryService.syncAssociations(
                        record: record,
                        selectedProductions: selectedProductions,
                        operatorName: currentUser?.name ?? "Operatore",
                        links: dataStore.links,
                        modelContext: modelContext
                    )
                    dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
                    showProductionSelection = false
                } catch {
                    errorMessage = "Associazione produzione non riuscita."
                }
            }
        )
        .environmentObject(appState)
    }

    @ViewBuilder
    private var labelEditorSheet: some View {
        if let draft = labelDraft,
           let rid = appState.activeRestaurantId,
           let user = currentUser {
            ProductionLabelEditorSheet(
                mode: .create(draft),
                restaurantId: rid,
                user: user,
                onSaved: { record, shouldPrint in
                    handleLabelSaved(record, shouldPrint: shouldPrint)
                },
                onCancel: { labelDraft = nil }
            )
        }
    }

    @ViewBuilder
    private var masterDeleteOverlay: some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .deleteTraceabilityEntry,
                onAuthorized: {
                    showMasterAuthDelete = false
                    if let record = recordPendingDelete {
                        do {
                            try service.deleteTraceabilityEntry(
                                record: record,
                                goodsReceipts: dataStore.goodsReceipts,
                                links: dataStore.links,
                                logs: dataStore.logs,
                                images: dataStore.images,
                                modelContext: modelContext
                            )
                            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
                        } catch {
                            errorMessage = "Eliminazione non riuscita."
                        }
                        recordPendingDelete = nil
                    }
                },
                onCancel: {
                    showMasterAuthDelete = false
                    recordPendingDelete = nil
                }
            ) { EmptyView() }
        }
    }

    private func beginLabel(for record: TraceabilityRecord) {
        let draft = labelService.draft(from: record)
        if let existing = ProductionLabelLinkMatcher.existingLabel(for: draft, in: scopedLabels) {
            appState.pendingSidebarNavigation = .productionLabels
            errorMessage = "Etichetta già presente per «\(existing.productName)». Vai in Etichette → Tracciabilità per ristampare."
            return
        }
        labelDraft = draft
    }

    private func beginProductionAssociation(_ record: TraceabilityRecord) {
        selectedTraceabilityForProduction = record
        pendingProductionIds = Set(dataStore.links.filter { $0.receivedItemId == record.id }.map(\.productionId))
        showProductionSelection = true
    }

    private func handleLabelSaved(_ record: ProductionLabelRecord, shouldPrint: Bool) {
        labelDraft = nil
        guard shouldPrint else { return }
        Task {
            await ProductionLabelPrintQueue.shared.schedulePrint(
                label: record,
                restaurantName: activeRestaurant?.name,
                modelContext: modelContext,
                countAsReprint: false
            )
        }
    }

    private func beginNonCompliance(_ record: TraceabilityRecord) {
        nonComplianceRecord = record
        nonComplianceNote = ""
        nonComplianceCorrectiveAction = ""
        nonCompliancePhotoData = nil
        ncCamera.resetCaptureBuffer()
    }

    private func refreshExpiredStatuses() {
        let expired = expiryService.refreshStatuses(records: dataStore.records, modelContext: modelContext)
        if expired > 0 {
            errorMessage = "Sono stati marcati \(expired) prodotti come scaduti."
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
    }

    @ViewBuilder
    private var nonComplianceSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Motivo, azione correttiva e foto sono obbligatori per registrare una criticità.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Motivo (non conformità)") {
                    TextField("Es. confezione danneggiata, temperatura errata…", text: $nonComplianceNote, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Azione correttiva") {
                    TextField("Cosa fate per gestire la criticità", text: $nonComplianceCorrectiveAction, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Foto obbligatoria") {
                    if let data = nonCompliancePhotoData,
                       let preview = HACCPZoomablePhotoPreview(data: data, height: 220, zoomTitle: "Foto non conformità") {
                        preview
                        Button("Riscatta foto") {
                            nonCompliancePhotoData = nil
                            ncCamera.resetCaptureBuffer()
                            ncCamera.start()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.colorCameraPreviewBackground)
                            .frame(height: 160)
                            .overlay(
                                Group {
                                    if ncCamera.authorizationDenied {
                                        Text("Accesso fotocamera negato")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        FinalizeCameraSessionPreview(session: ncCamera.session)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            )
                        Button("Scatta foto") {
                            ncAwaitingCapture = true
                            ncCamera.capturePhoto()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(ncCamera.authorizationDenied)
                    }
                }
            }
            .navigationTitle("Non conformità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        ncAwaitingCapture = false
                        ncCamera.stop()
                        nonComplianceRecord = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") { confirmNonCompliance() }
                }
            }
            .onAppear {
                ncCamera.resetCaptureBuffer()
                ncCamera.start()
            }
            .onDisappear {
                ncAwaitingCapture = false
                ncCamera.stop()
            }
        }
    }

    private func confirmNonCompliance() {
        guard let record = nonComplianceRecord else { return }
        guard let user = currentUser else {
            errorMessage = "Effettua l'accesso per registrare la non conformità."
            return
        }
        let note = nonComplianceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = nonComplianceCorrectiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, !action.isEmpty, let photo = nonCompliancePhotoData, !photo.isEmpty else {
            errorMessage = "Per una non conformità è obbligatorio allegare una foto."
            return
        }
        do {
            try service.markNonCompliant(
                record: record,
                note: note,
                correctiveAction: action,
                imageData: photo,
                user: user,
                modelContext: modelContext
            )
            ncAwaitingCapture = false
            ncCamera.stop()
            nonComplianceRecord = nil
            nonCompliancePhotoData = nil
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Lookup contesto (indici pre-calcolati per lista veloce)

private struct TraceabilityContext {
    let receiptsById: [UUID: GoodsReceipt]
    let productionIdsByRecord: [UUID: Set<UUID>]
    let productionsById: [UUID: Production]
    let defrostByTrace: [UUID: [DefrostRecord]]
    let imagesByRecord: [UUID: [ProductImage]]

    init(store: TraceabilityDataStore) {
        receiptsById = Dictionary(uniqueKeysWithValues: store.goodsReceipts.map { ($0.id, $0) })
        productionsById = Dictionary(uniqueKeysWithValues: store.productions.map { ($0.id, $0) })
        var prodMap: [UUID: Set<UUID>] = [:]
        for link in store.links {
            prodMap[link.receivedItemId, default: []].insert(link.productionId)
        }
        productionIdsByRecord = prodMap
        var defrostMap: [UUID: [DefrostRecord]] = [:]
        for defrost in store.defrostRecords {
            if let traceId = defrost.traceabilityItemId {
                defrostMap[traceId, default: []].append(defrost)
            }
        }
        defrostByTrace = defrostMap
        var imageMap: [UUID: [ProductImage]] = [:]
        for image in store.images {
            imageMap[image.receivedItemId, default: []].append(image)
        }
        imagesByRecord = imageMap
    }

    func receipt(for record: TraceabilityRecord) -> GoodsReceipt? {
        guard let gid = record.goodsReceiptId else { return nil }
        return receiptsById[gid]
    }

    func productName(for record: TraceabilityRecord) -> String {
        receipt(for: record)?.productNameSnapshot ?? record.productName
    }

    func supplier(for record: TraceabilityRecord) -> String {
        let s = receipt(for: record)?.supplierNameSnapshot ?? record.supplier
        return s.isEmpty ? "-" : s
    }

    func lot(for record: TraceabilityRecord) -> String {
        let lot = receipt(for: record)?.lotNumber ?? (record.lotCode.isEmpty ? nil : record.lotCode)
        guard let lot, !lot.isEmpty else { return "-" }
        return lot
    }

    func receivedAt(for record: TraceabilityRecord) -> Date {
        receipt(for: record)?.receivedAt ?? record.receivedAt
    }

    func expiryDate(for record: TraceabilityRecord) -> Date? {
        receipt(for: record)?.expiryDate ?? record.expiryDate
    }

    func category(for record: TraceabilityRecord) -> String? {
        if let r = receipt(for: record) {
            return r.category.rawValue
        }
        if let raw = record.categoryRaw {
            return GoodsCategory(rawValue: raw)?.rawValue ?? raw
        }
        return nil
    }

    func receiptStatusLabel(for record: TraceabilityRecord) -> String? {
        receipt(for: record)?.status.label
    }

    func matchesSearch(_ record: TraceabilityRecord, query: String) -> Bool {
        let q = query.lowercased()
        return productName(for: record).lowercased().contains(q)
            || lot(for: record).lowercased().contains(q)
            || supplier(for: record).lowercased().contains(q)
    }

    func associatedProductions(for record: TraceabilityRecord) -> [Production] {
        let ids = productionIdsByRecord[record.id] ?? []
        return ids.compactMap { productionsById[$0] }.sorted { $0.name < $1.name }
    }

    func defrostRecords(for record: TraceabilityRecord) -> [DefrostRecord] {
        defrostByTrace[record.id] ?? []
    }

    func display(for record: TraceabilityRecord) -> TraceabilityRecordDisplay {
        let expiry = expiryDate(for: record)
        let thresholdDays = SettingsStorageService.shared.haccp.productExpiryThreshold
        let soon = Calendar.current.date(byAdding: .day, value: thresholdDays, to: Date()) ?? Date()
        let expiryWarning = expiry.map { $0 <= soon && $0 >= Date() } ?? false
        let status = ProductExpiryEvaluator.effectiveDisplayStatus(record, expiryDate: expiry)
        let actionable = status != .expired && status != .rejected && record.productStatus != .used
        return TraceabilityRecordDisplay(
            recordId: record.id,
            productName: productName(for: record),
            lot: lot(for: record),
            supplier: supplier(for: record),
            receivedAt: receivedAt(for: record),
            expiryDate: expiry,
            category: category(for: record),
            statusLabel: record.isNonCompliant ? "Non conforme" : status.label,
            badgeStyle: badgeStyle(for: status, isNonCompliant: record.isNonCompliant),
            productionCount: productionIdsByRecord[record.id]?.count ?? 0,
            defrostCount: defrostByTrace[record.id]?.count ?? 0,
            isActionable: actionable,
            expiryWarning: expiryWarning
        )
    }

    func image(for record: TraceabilityRecord) -> UIImage? {
        let recordImages = (imagesByRecord[record.id] ?? []).sorted { $0.createdAt > $1.createdAt }
        let preferred = recordImages.first { $0.type == .nonComplianceRequired }
            ?? recordImages.first { $0.type == .receiptOptional }
            ?? recordImages.first
        if let imgModel = preferred,
           let bytes = imgModel.imageData, !bytes.isEmpty,
           let image = UIImage(data: bytes) {
            return image
        }
        if let path = preferred?.localPath, let image = UIImage(contentsOfFile: path) {
            return image
        }
        if let data = receipt(for: record)?.photoData, let image = UIImage(data: data) {
            return image
        }
        if let data = record.photoData, let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    private func badgeStyle(for status: ProductStatus, isNonCompliant: Bool) -> HACCPBadgeStyle {
        if isNonCompliant { return .nonConforme }
        switch status {
        case .available: return .info
        case .partiallyUsed: return .warning
        case .used: return .conforme
        case .expired, .rejected: return .nonConforme
        }
    }
}
