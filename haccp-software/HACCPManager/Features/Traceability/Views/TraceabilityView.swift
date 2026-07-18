import SwiftUI
import SwiftData

struct TraceabilityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var session: RestaurantSessionContext

    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.traceability

    @State private var searchText = ""
    @State private var selectedFilter: TraceabilityHubFilter = .today
    @State private var expandedArchiveGroupIds: Set<String> = []
    @State private var displayLimit = 40
    @State private var auxiliaryCategories: [ProductionCategory] = []
    @State private var auxiliaryLabels: [ProductionLabelRecord] = []
    @State private var hubContext = TraceabilityHubContext(
        records: [],
        productions: [],
        links: [],
        lottoProductionLinks: []
    )
    @State private var hubSnapshot = TraceabilityHubSnapshot.empty
    @State private var auxiliaryLoadTask: Task<Void, Never>?

    @State private var showLotCapture = false
    @State private var resumeSessionId: UUID?
    @State private var dismissedSessionIds: Set<UUID> = []

    @State private var detailRecord: TraceabilityRecord?
    @State private var quickAssociateRecord: TraceabilityRecord?
    @State private var multiAssociateRecord: TraceabilityRecord?
    @State private var pendingProductionIds: Set<UUID> = []
    @State private var showProductionSelection = false

    @State private var nonComplianceRecord: TraceabilityRecord?
    @State private var labelDraft: ProductionLabelDraft?

    @State private var recordPendingDelete: TraceabilityRecord?
    @State private var errorMessage: String?
    @State private var openSessions: [TraceabilityOpenSession] = []
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var showActiveLottiList = false
    @State private var sessionToDelete: TraceabilityOpenSession? = nil

    private let productionLibraryService = ProductionLibraryService()
    private let service = TraceabilityService()
    private let labelService = ProductionLabelsService()
    private let lottoService = LottoFotoService()

    private func toggleArchiveGroup(_ groupId: String) {
        if expandedArchiveGroupIds.contains(groupId) {
            expandedArchiveGroupIds.remove(groupId)
        } else {
            expandedArchiveGroupIds.insert(groupId)
        }
    }

    private func rebuildHubSnapshot() {
        hubSnapshot = TraceabilityHubSnapshotBuilder.build(
            context: hubContext,
            records: dataStore.records,
            filter: selectedFilter,
            searchText: searchText
        )
    }

    private func rebuildHubContext() {
        hubContext = TraceabilityHubContext(store: dataStore)
        rebuildHubSnapshot()
    }

    private var metrics: TraceabilityHubMetrics {
        hubSnapshot.metrics
    }

    private var filteredRecords: [TraceabilityRecord] {
        hubSnapshot.filteredRecords
    }

    private var productionArchiveGroups: [TraceabilityProductionArchiveGroup] {
        hubSnapshot.productionGroups
    }

    private var unlinkedRecords: [TraceabilityRecord] {
        hubSnapshot.unlinkedRecords
    }

    private var productionSearchSuggestions: [String] {
        hubSnapshot.productionSuggestions
    }

    private var visibleProductionGroups: [TraceabilityProductionArchiveGroup] {
        Array(productionArchiveGroups.prefix(displayLimit))
    }

    private var criticalRecords: [TraceabilityRecord] {
        hubSnapshot.criticalRecords
    }

    private var visibleCriticalRecords: [TraceabilityRecord] {
        Array(criticalRecords.prefix(displayLimit))
    }

    private var visibleUnlinkedRecords: [TraceabilityRecord] {
        Array(unlinkedRecords.prefix(displayLimit))
    }

    private var currentUser: LocalUser? {
        session.currentUser
    }

    private var activeRestaurant: Restaurant? {
        session.activeRestaurant
    }

    private var scopedLabels: [ProductionLabelRecord] {
        auxiliaryLabels
    }

    private var scopedCategories: [ProductionCategory] {
        auxiliaryCategories
    }

    private var permissions: UserPermissions { currentUser?.permissions ?? UserPermissions(role: .viewer) }
    private var canDeleteRecords: Bool { permissions.can(.deleteTraceabilityRecords) }

    private var activeOpenSession: TraceabilityOpenSession? {
        openSessions.first { !dismissedSessionIds.contains($0.id) }
    }

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                emptyRestaurant
            } else if dataStore.isLoading && dataStore.records.isEmpty && dataStore.productions.isEmpty {
                ProgressView("Caricamento tracciabilità…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                hubScroll
                    .opacity(dataStore.isLoading ? 0.7 : 1)
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Tracciabilità")
        .haccpControlTint()
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            reloadAll()
        }
        .onChange(of: dataStore.loadGeneration) { _, _ in
            rebuildHubContext()
        }
        .alert("Tracciabilità", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showLotCapture) { lotCaptureOverlay }
        .sheet(item: $detailRecord) { record in detailSheet(for: record) }
        .sheet(item: $quickAssociateRecord) { record in quickAssociateSheet(for: record) }
        .sheet(isPresented: $showProductionSelection) { productionSelectionSheet }
        .sheet(item: $nonComplianceRecord) { record in
            if let user = currentUser {
                TraceabilityNonComplianceSheet(
                    record: record,
                    user: user,
                    onSaved: {
                        nonComplianceRecord = nil
                        reloadAll()
                    },
                    onCancel: { nonComplianceRecord = nil }
                )
            }
        }
        .sheet(isPresented: Binding(get: { labelDraft != nil }, set: { if !$0 { labelDraft = nil } })) {
            labelEditorSheet
        }
        .sheet(isPresented: $showActiveLottiList) {
            if let rid = appState.activeRestaurantId {
                TraceabilityActiveLottiListView(restaurantId: rid) {
                    showActiveLottiList = false
                    reloadAll()
                }
            }
        }
        .alert("Eliminare la sessione?", isPresented: Binding(get: { sessionToDelete != nil }, set: { _ in sessionToDelete = nil })) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                if let session = sessionToDelete {
                    performDeleteSession(session)
                }
            }
        } message: {
            Text("Tutte le foto scattate in questa sessione verranno rimosse permanentemente.")
        }
        .masterAuthCover(
            coordinator: masterAuth,
            master: session.masterUser
        )
    }

    // MARK: - Hub

    private var emptyRestaurant: some View {
        DashboardEmptyStateView(state: .init(
            title: "Seleziona un ristorante",
            message: "La tracciabilità è legata al ristorante attivo.",
            actionTitle: nil
        ))
        .padding(theme.spacing.screenPadding)
    }

    private var hubScroll: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Tracciabilità",
                    subtitle: "Scatta etichette, collega alimenti e piatti",
                    systemImage: "archivebox.fill",
                    help: ModuleHelpLibrary.sidebar(.traceability)
                )

                TraceabilityWorkflowGuideCard()

                metricsGrid

                actionRow

                if let session = activeOpenSession {
                    TraceabilityOpenSessionCard(
                        session: session,
                        onResume: {
                            resumeSessionId = session.id
                            showLotCapture = true
                        },
                        onDismiss: {
                            sessionToDelete = session
                        }
                    )
                }

                TraceabilityFilterBar(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    productionSuggestions: productionSearchSuggestions
                )
                .onChange(of: searchText) { _, _ in
                    displayLimit = 40
                    rebuildHubSnapshot()
                    if !searchText.isEmpty {
                        expandedArchiveGroupIds = Set(hubSnapshot.productionGroups.map(\.id))
                    }
                }
                .onChange(of: selectedFilter) { _, _ in
                    displayLimit = 40
                    rebuildHubSnapshot()
                }

                recordsSection
            }
            .padding(theme.spacing.screenPadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            TraceabilityMetricTile(
                title: "Oggi",
                value: "\(metrics.todayCount)",
                subtitle: "Registrati oggi",
                icon: "calendar",
                accent: theme.colorWarning,
                isActive: selectedFilter == .today
            ) { selectedFilter = .today }

            TraceabilityMetricTile(
                title: "Da associare",
                value: "\(metrics.unlinked)",
                subtitle: "Senza piatto",
                icon: "link.badge.plus",
                accent: theme.colorInfo,
                isActive: selectedFilter == .unlinked
            ) { selectedFilter = .unlinked }

            TraceabilityMetricTile(
                title: "Non conformi",
                value: "\(metrics.critical)",
                subtitle: "Da verificare",
                icon: "exclamationmark.triangle.fill",
                accent: theme.colorError,
                isActive: selectedFilter == .critical
            ) { selectedFilter = .critical }

            TraceabilityMetricTile(
                title: "Totale lotti",
                value: "\(metrics.total)",
                subtitle: "In archivio",
                icon: "archivebox.fill",
                accent: theme.colorPrimary,
                isActive: selectedFilter == .all
            ) { selectedFilter = .all }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Inizia sessione lotti", icon: "camera.fill") {
                resumeSessionId = nil
                showLotCapture = true
            }

            Button {
                showActiveLottiList = true
            } label: {
                Label("Visualizza lotti in magazzino", systemImage: "archivebox.fill")
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colorPrimary)
            }
            .buttonStyle(.plain)

            if metrics.todayCount > 0 {
                Button {
                    selectedFilter = .today
                } label: {
                    Label("\(metrics.todayCount) lotti registrati oggi", systemImage: "calendar")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recordsSection: some View {
        VStack(spacing: theme.spacing.sectionSpacing) {
            switch selectedFilter {
            case .critical:
                if criticalRecords.isEmpty {
                    emptyRecordsCard
                } else {
                    criticalRecordsCard
                }

            case .unlinked:
                if unlinkedRecords.isEmpty {
                    emptyRecordsCard
                } else {
                    unlinkedRecordsCard(title: recordsSectionTitle)
                }

            case .today:
                if !unlinkedRecords.isEmpty {
                    unlinkedRecordsCard(title: "Da associare oggi")
                }
                if !productionArchiveGroups.isEmpty {
                    productionArchiveCard
                }
                if unlinkedRecords.isEmpty && productionArchiveGroups.isEmpty {
                    emptyRecordsCard
                }

            case .all:
                if !unlinkedRecords.isEmpty {
                    unlinkedRecordsCard(title: "Lotti da associare")
                }
                if !productionArchiveGroups.isEmpty {
                    productionArchiveCard
                }
                if unlinkedRecords.isEmpty && productionArchiveGroups.isEmpty {
                    emptyRecordsCard
                }
            }
        }
    }

    private var productionArchiveCard: some View {
        DashboardCardView(
            title: recordsSectionTitle,
            subtitle: "\(productionArchiveGroups.count) piatti · \(filteredRecords.count) lotti"
        ) {
            VStack(spacing: 12) {
                ForEach(visibleProductionGroups) { group in
                    TraceabilityProductionArchiveCard(
                        group: group,
                        searchText: searchText,
                        isExpanded: expandedArchiveGroupIds.contains(group.id),
                        onToggleExpanded: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                toggleArchiveGroup(group.id)
                            }
                        },
                        onOpenIngredient: { recordId in
                            openRecord(id: recordId)
                        },
                        onDeleteIngredient: canDeleteRecords
                            ? { recordId in requestDeleteRecord(id: recordId) }
                            : nil
                    )
                    .equatable()
                    .contextMenu {
                        if canDeleteRecords {
                            Button(role: .destructive) {
                                requestDeleteProductionGroup(group)
                            } label: {
                                Label("Rimuovi piatto", systemImage: "trash")
                            }
                        }
                    }
                }

                if productionArchiveGroups.count > displayLimit {
                    SecondaryButton(
                        title: "Carica altri (\(productionArchiveGroups.count - displayLimit))",
                        icon: "arrow.down.circle"
                    ) {
                        displayLimit += 40
                    }
                }
            }
        }
    }

    private func unlinkedRecordsCard(title: String) -> some View {
        DashboardCardView(
            title: title,
            subtitle: "\(unlinkedRecords.count) senza piatto"
        ) {
            VStack(spacing: 10) {
                ForEach(visibleUnlinkedRecords) { record in
                    let display = hubContext.display(for: record)
                    SwipeToDeleteRow(
                        enabled: canDeleteRecords,
                        deleteTitle: "Elimina",
                        onDelete: { requestDeleteUnlinkedRecord(record) }
                    ) {
                        TraceabilityRecordCard(
                            display: display,
                            onTap: { detailRecord = record },
                            onQuickAssociate: display.needsProductionLink ? {
                                quickAssociateRecord = record
                            } : nil
                        )
                    }
                }

                if unlinkedRecords.count > visibleUnlinkedRecords.count {
                    SecondaryButton(
                        title: "Carica altri (\(unlinkedRecords.count - visibleUnlinkedRecords.count))",
                        icon: "arrow.down.circle"
                    ) {
                        displayLimit += 40
                    }
                }
            }
        }
    }

    private var criticalRecordsCard: some View {
        DashboardCardView(
            title: recordsSectionTitle,
            subtitle: "\(criticalRecords.count) da verificare"
        ) {
            LazyVStack(spacing: 10) {
                ForEach(visibleCriticalRecords) { record in
                    let display = hubContext.display(for: record)
                    SwipeToDeleteRow(
                        enabled: canDeleteRecords,
                        deleteTitle: "Elimina",
                        onDelete: { requestDeleteUnlinkedRecord(record) }
                    ) {
                        TraceabilityRecordCard(
                            display: display,
                            onTap: { detailRecord = record },
                            onQuickAssociate: display.needsProductionLink ? {
                                quickAssociateRecord = record
                            } : nil
                        )
                    }
                }

                if criticalRecords.count > visibleCriticalRecords.count {
                    SecondaryButton(
                        title: "Carica altri (\(criticalRecords.count - visibleCriticalRecords.count))",
                        icon: "arrow.down.circle"
                    ) {
                        displayLimit += 40
                    }
                }
            }
        }
    }

    private var emptyRecordsCard: some View {
        DashboardCardView(
            title: recordsSectionTitle,
            subtitle: recordsSectionSubtitle
        ) {
            emptyRecordsState
        }
    }

    private var recordsSectionTitle: String {
        switch selectedFilter {
        case .all: return "Archivio per piatto"
        case .unlinked: return "Lotti da associare"
        case .critical: return "Non conformi"
        case .today: return "Piatti di oggi"
        }
    }

    private var recordsSectionSubtitle: String {
        "\(filteredRecords.count) risultati"
    }

    @ViewBuilder
    private var emptyRecordsState: some View {
        DashboardEmptyStateView(state: .init(
            title: emptyTitle,
            message: emptyMessage,
            actionTitle: emptyActionTitle
        )) {
            if searchText.isEmpty && (selectedFilter == .all || selectedFilter == .today) {
                showLotCapture = true
            } else if selectedFilter == .unlinked || selectedFilter == .critical {
                selectedFilter = .today
            } else {
                selectedFilter = .today
                searchText = ""
            }
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return "Nessun risultato" }
        switch selectedFilter {
        case .unlinked: return "Tutto associato"
        case .critical: return "Nessuna non conformità"
        case .today: return "Niente registrato oggi"
        case .all: return "Archivio vuoto"
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "Prova a cambiare ricerca o filtro."
        }
        switch selectedFilter {
        case .unlinked:
            return "Ogni lotto attivo è collegato a un piatto."
        case .critical:
            return "Non ci sono lotti segnalati come non conformi."
        case .today:
            return "Usa la fotocamera per registrare i lotti di oggi."
        case .all:
            return "Scatta le etichette con la fotocamera per iniziare."
        }
    }

    private var emptyActionTitle: String? {
        if !searchText.isEmpty { return "Reimposta filtri" }
        switch selectedFilter {
        case .all, .today: return "Scatta lotti"
        case .unlinked, .critical: return "Vedi oggi"
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func detailSheet(for record: TraceabilityRecord) -> some View {
        TraceabilityRecordDetailSheet(
            record: record,
            display: hubContext.display(for: record),
            associatedProductions: hubContext.associatedProductions(for: record),
            ingredientCountByProductionId: Dictionary(
                uniqueKeysWithValues: hubContext.associatedProductions(for: record).map {
                    ($0.id, hubContext.ingredientCount(forProduction: $0.id))
                }
            ),
            linkedIngredientCount: hubContext.ingredientCount(for: record),
            defrostRecords: hubContext.defrostRecords(for: record),
            auditLogs: hubContext.auditLogs(for: record),
            productionsById: Dictionary(dataStore.productions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            canDeleteRecords: canDeleteRecords,
            hasExistingLabel: {
                let draft = labelService.draft(from: record)
                return ProductionLabelLinkMatcher.existingLabel(for: draft, in: scopedLabels) != nil
            }(),
            masterUser: session.masterUser,
            onAssociate: { beginMultiProductionAssociation(record) },
            onLabel: { beginLabel(for: record) },
            onNonCompliant: { nonComplianceRecord = record },
            onDelete: {
                recordPendingDelete = record
                performPendingDelete()
                detailRecord = nil
            },
            onDismiss: { detailRecord = nil }
        )
    }

    @ViewBuilder
    private func quickAssociateSheet(for record: TraceabilityRecord) -> some View {
        TraceabilityQuickAssociateSheet(
            record: record,
            productions: dataStore.productions,
            categories: scopedCategories,
            onConfirm: { production in
                associate(record: record, to: production)
                quickAssociateRecord = nil
            },
            onCancel: { quickAssociateRecord = nil }
        )
    }

    private var productionSelectionSheet: some View {
        ProductionSelectionView(
            initialSelectedIds: pendingProductionIds,
            onCancel: { showProductionSelection = false },
            onConfirm: { selectedProductions in
                guard let record = multiAssociateRecord else { return }
                do {
                    try productionLibraryService.syncAssociations(
                        record: record,
                        selectedProductions: selectedProductions,
                        operatorName: currentUser?.name ?? "Operatore",
                        links: dataStore.links,
                        modelContext: modelContext
                    )
                    reloadAll()
                    showProductionSelection = false
                } catch {
                    errorMessage = "Associazione non riuscita."
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
    private var lotCaptureOverlay: some View {
        if let rid = appState.activeRestaurantId, let user = currentUser {
            TraceabilityLotCaptureFlowView(
                restaurantId: rid,
                user: user,
                resumeSessionId: resumeSessionId,
                onDismiss: { leavePending, sessionId in
                    if let sessionId {
                        if leavePending {
                            dismissedSessionIds.remove(sessionId)
                        } else {
                            dismissedSessionIds.insert(sessionId)
                        }
                    }
                    showLotCapture = false
                    resumeSessionId = nil
                    reloadAll()
                },
                onUpdated: { reloadAll() }
            )
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                ProgressView("Preparazione fotocamera…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
            .onAppear {
                if appState.activeRestaurantId == nil {
                    showLotCapture = false
                }
            }
        }
    }

    // MARK: - Actions

    private func openRecord(id: UUID) {
        if let record = dataStore.records.first(where: { $0.id == id }) {
            detailRecord = record
        }
    }

    private func performPendingDelete() {
        guard let record = recordPendingDelete else { return }
        do {
            try service.deleteTraceabilityEntry(
                record: record,
                links: dataStore.links,
                logs: dataStore.logs,
                images: dataStore.images,
                modelContext: modelContext
            )
            recordPendingDelete = nil
            reloadAll()
        } catch {
            errorMessage = "Eliminazione non riuscita."
            recordPendingDelete = nil
        }
    }

    private func performDeleteSession(_ session: TraceabilityOpenSession) {
        do {
            let targetSessionId = session.id
            let descriptor = FetchDescriptor<LottoFoto>()
            let allLottos = (try? modelContext.fetch(descriptor)) ?? []
            let sessionLottos = allLottos.filter { $0.traceabilitySessionId == targetSessionId }
            for lotto in sessionLottos {
                try lottoService.delete(lotto, modelContext: modelContext)
            }
            dismissedSessionIds.insert(session.id)
            reloadAll()
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = "Impossibile eliminare la sessione: \(error.localizedDescription)"
        }
    }

    private func requestDeleteUnlinkedRecord(_ record: TraceabilityRecord) {
        masterAuth.request(
            permission: .deleteTraceabilityRecords,
            permissions: permissions,
            action: {
                recordPendingDelete = record
                performPendingDelete()
            }
        )
    }

    private func requestDeleteRecord(id: UUID) {
        guard let record = dataStore.records.first(where: { $0.id == id }) else { return }
        requestDeleteUnlinkedRecord(record)
    }

    private func requestDeleteProductionGroup(_ group: TraceabilityProductionArchiveGroup) {
        masterAuth.request(
            permission: .deleteTraceabilityRecords,
            permissions: permissions,
            action: { performDeleteProductionGroup(group) }
        )
    }

    private func performDeleteProductionGroup(_ group: TraceabilityProductionArchiveGroup) {
        do {
            try productionLibraryService.removeProductionGroup(
                group: group,
                records: dataStore.records,
                links: dataStore.links,
                lottoProductionLinks: dataStore.lottoProductionLinks,
                productionsById: Dictionary(dataStore.productions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
                modelContext: modelContext
            )
            reloadAll()
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = "Rimozione piatto non riuscita."
        }
    }

    private func reloadAll() {
        let rid = appState.activeRestaurantId
        dataStore.reload(context: modelContext, restaurantId: rid, force: true)
        auxiliaryLoadTask?.cancel()
        guard let rid else {
            openSessions = []
            auxiliaryCategories = []
            auxiliaryLabels = []
            return
        }
        auxiliaryLoadTask = Task(priority: .utility) { @MainActor in
            await Task.yield()
            var categoryDescriptor = FetchDescriptor<ProductionCategory>(
                predicate: #Predicate { $0.restaurantId == rid },
                sortBy: [SortDescriptor(\ProductionCategory.orderIndex)]
            )
            categoryDescriptor.fetchLimit = 100
            auxiliaryCategories = (try? modelContext.fetch(categoryDescriptor)) ?? []
            await Task.yield()
            guard !Task.isCancelled else { return }

            var labelDescriptor = FetchDescriptor<ProductionLabelRecord>(
                predicate: #Predicate { $0.restaurantId == rid },
                sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse)]
            )
            labelDescriptor.fetchLimit = 200
            auxiliaryLabels = (try? modelContext.fetch(labelDescriptor)) ?? []
            await Task.yield()
            guard !Task.isCancelled else { return }

            lottoService.ensureArchiveRecords(restaurantId: rid, modelContext: modelContext)
            guard !Task.isCancelled else { return }
            openSessions = lottoService.openSessions(restaurantId: rid, modelContext: modelContext)
        }
    }

    private func beginMultiProductionAssociation(_ record: TraceabilityRecord) {
        multiAssociateRecord = record
        pendingProductionIds = Set(dataStore.links.filter { $0.receivedItemId == record.id }.map(\.productionId))
        showProductionSelection = true
    }

    private func associate(record: TraceabilityRecord, to production: Production) {
        do {
            try productionLibraryService.associate(
                record: record,
                production: production,
                quantityUsed: nil,
                operatorName: currentUser?.name ?? "Operatore",
                links: dataStore.links,
                modelContext: modelContext
            )
            reloadAll()
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func beginLabel(for record: TraceabilityRecord) {
        let draft = labelService.draft(from: record)
        if let existing = ProductionLabelLinkMatcher.existingLabel(for: draft, in: scopedLabels) {
            appState.pendingSidebarNavigation = .productionLabels
            errorMessage = "Etichetta già presente per «\(existing.productName)». Vai in Etichette per ristampare."
            return
        }
        labelDraft = draft
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
}
