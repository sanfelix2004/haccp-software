import SwiftUI
import SwiftData

struct TraceabilityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var productionLabels: [ProductionLabelRecord]
    @Query private var categories: [ProductionCategory]

    @StateObject private var dataStore = TraceabilityDataStore()

    @State private var searchText = ""
    @State private var selectedFilter: TraceabilityHubFilter = .all
    @State private var displayLimit = 40

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

    private let productionLibraryService = ProductionLibraryService()
    private let service = TraceabilityService()
    private let labelService = ProductionLabelsService()
    private let lottoService = LottoFotoService()

    private var hubContext: TraceabilityHubContext {
        TraceabilityHubContext(store: dataStore)
    }

    private var metrics: TraceabilityHubMetrics {
        hubContext.metrics(for: dataStore.records)
    }

    private var filteredRecords: [TraceabilityRecord] {
        hubContext.filteredRecords(dataStore.records, filter: selectedFilter, searchText: searchText)
    }

    private var productionArchiveGroups: [TraceabilityProductionArchiveGroup] {
        hubContext.productionArchiveGroups(
            records: dataStore.records,
            filter: selectedFilter,
            searchText: searchText
        )
    }

    private var unlinkedRecords: [TraceabilityRecord] {
        hubContext.unlinkedRecords(
            records: dataStore.records,
            filter: selectedFilter,
            searchText: searchText
        )
    }

    private var productionSearchSuggestions: [String] {
        var seen = Set<String>()
        return hubContext
            .productionArchiveGroups(records: dataStore.records, filter: .all, searchText: "")
            .compactMap { group -> String? in
                let name = group.productionName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
                return name
            }
            .prefix(12)
            .map { $0 }
    }

    private var visibleProductionGroups: [TraceabilityProductionArchiveGroup] {
        Array(productionArchiveGroups.prefix(displayLimit))
    }

    private var visibleUnlinkedRecords: [TraceabilityRecord] {
        Array(unlinkedRecords.prefix(displayLimit))
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var activeRestaurant: Restaurant? {
        guard let rid = appState.activeRestaurantId else { return nil }
        return restaurants.first { $0.id == rid }
    }

    private var scopedLabels: [ProductionLabelRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return productionLabels.filter { $0.restaurantId == rid }
    }

    private var scopedCategories: [ProductionCategory] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return categories.filter { $0.restaurantId == rid }.sorted { $0.orderIndex < $1.orderIndex }
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
        .task(id: appState.activeRestaurantId) {
            reloadAll()
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
        .masterAuthCover(
            coordinator: masterAuth,
            master: users.first(where: { $0.role == .master })
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
                            dismissedSessionIds.insert(session.id)
                        }
                    )
                }

                TraceabilityFilterBar(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    productionSuggestions: productionSearchSuggestions
                )
                .onChange(of: searchText) { _, _ in displayLimit = 40 }
                .onChange(of: selectedFilter) { _, _ in displayLimit = 40 }

                recordsSection
            }
            .padding(theme.spacing.screenPadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            TraceabilityMetricTile(
                title: "Totale lotti",
                value: "\(metrics.total)",
                subtitle: "In archivio",
                icon: "archivebox.fill",
                accent: theme.colorPrimary,
                isActive: selectedFilter == .all
            ) { selectedFilter = .all }

            TraceabilityMetricTile(
                title: "Da associare",
                value: "\(metrics.unlinked)",
                subtitle: "Senza piatto",
                icon: "link.badge.plus",
                accent: theme.colorInfo,
                isActive: selectedFilter == .unlinked
            ) { selectedFilter = .unlinked }

            TraceabilityMetricTile(
                title: "Oggi",
                value: "\(metrics.todayCount)",
                subtitle: "Registrati oggi",
                icon: "calendar",
                accent: theme.colorWarning,
                isActive: selectedFilter == .today
            ) { selectedFilter = .today }

            TraceabilityMetricTile(
                title: "Non conformi",
                value: "\(metrics.critical)",
                subtitle: "Da verificare",
                icon: "exclamationmark.triangle.fill",
                accent: theme.colorError,
                isActive: selectedFilter == .critical
            ) { selectedFilter = .critical }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Inizia sessione lotti", icon: "camera.fill") {
                resumeSessionId = nil
                showLotCapture = true
            }

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
            if !productionArchiveGroups.isEmpty {
                DashboardCardView(
                    title: recordsSectionTitle,
                    subtitle: "\(productionArchiveGroups.count) piatti · \(filteredRecords.count) lotti"
                ) {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleProductionGroups) { group in
                            SwipeToDeleteRow(
                                enabled: canDeleteRecords,
                                deleteTitle: "Rimuovi piatto",
                                onDelete: { requestDeleteProductionGroup(group) }
                            ) {
                                TraceabilityProductionArchiveCard(
                                    group: group,
                                    searchText: searchText,
                                    onOpenIngredient: { recordId in
                                        openRecord(id: recordId)
                                    }
                                )
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

            if !unlinkedRecords.isEmpty {
                DashboardCardView(
                    title: selectedFilter == .unlinked ? recordsSectionTitle : "Lotti da associare",
                    subtitle: "\(unlinkedRecords.count) senza piatto"
                ) {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleUnlinkedRecords) { record in
                            let display = hubContext.display(for: record)
                            TraceabilityRecordCard(
                                display: display,
                                onTap: { detailRecord = record },
                                onQuickAssociate: display.needsProductionLink ? {
                                    quickAssociateRecord = record
                                } : nil
                            )
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

            if productionArchiveGroups.isEmpty && unlinkedRecords.isEmpty {
                DashboardCardView(
                    title: recordsSectionTitle,
                    subtitle: recordsSectionSubtitle
                ) {
                    emptyRecordsState
                }
            }
        }
    }

    private var recordsSectionTitle: String {
        switch selectedFilter {
        case .all: return "Archivio per piatto"
        case .unlinked: return "Lotti da associare"
        case .critical: return "Non conformi"
        case .today: return "Registrati oggi"
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
            if searchText.isEmpty && selectedFilter == .all {
                showLotCapture = true
            } else if selectedFilter == .unlinked {
                selectedFilter = .all
            } else {
                selectedFilter = .all
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
        case .unlinked, .critical: return "Vedi tutti"
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
            masterUser: users.first(where: { $0.role == .master }),
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
                onDismiss: {
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
        if let rid = appState.activeRestaurantId {
            lottoService.ensureArchiveRecords(restaurantId: rid, modelContext: modelContext)
        }
        dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        if let rid = appState.activeRestaurantId {
            openSessions = lottoService.openSessions(restaurantId: rid, modelContext: modelContext)
        } else {
            openSessions = []
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
