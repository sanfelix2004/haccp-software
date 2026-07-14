import SwiftUI
import SwiftData

struct BlastChillingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var blastManager: ActiveBlastChillingManager
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.blastChilling
    @StateObject private var vm = BlastChillingViewModel()
    @State private var showNewSheet = false
    @State private var pendingSubject: KitchenProcessSubject?
    @State private var recordToComplete: BlastChillingRecord?
    @State private var labelDraft: ProductionLabelDraft?

    private let libraryService = ProductionLibraryService()
    private let labelService = ProductionLabelsService()

    private var scopedRecords: [BlastChillingRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    private var scopedCategories: [ProductionCategory] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.categories.filter { $0.restaurantId == rid }.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var scopedProductions: [Production] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.productions.filter { $0.restaurantId == rid }
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
        return dataStore.productionLabels.filter { $0.restaurantId == rid }
    }

    private var permissions: UserPermissions { currentUser.permissions }
    private var canExecute: Bool { permissions.can(.executeRecords) }

    private var filteredHistory: [BlastChillingRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: vm.historyStartDate)
        let endStart = calendar.startOfDay(for: vm.historyEndDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? vm.historyEndDate
        return scopedRecords.filter { record in
            guard record.status != .inCorso else { return false }
            let categoryOk: Bool = {
                guard let selected = vm.selectedHistoryCategoryId else { return true }
                return record.productionCategorySnapshot == scopedCategories.first(where: { $0.id == selected })?.name
            }()
            let statusOk = vm.selectedHistoryStatus == nil || record.status == vm.selectedHistoryStatus
            let operatorOk = vm.selectedHistoryOperator == "Tutti" || record.createdByNameSnapshot == vm.selectedHistoryOperator
            let anchor = record.endedAt ?? record.startedAt
            let periodOk = anchor >= start && anchor <= end
            return categoryOk && statusOk && operatorOk && periodOk
        }
        .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
    }

    private var operators: [String] {
        ["Tutti"] + Array(Set(scopedRecords.map(\.createdByNameSnapshot))).sorted()
    }

    private var inProgressRecords: [BlastChillingRecord] {
        scopedRecords
            .filter { $0.status == .inCorso }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var stats: (inProgress: Int, completedToday: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let completedToday = scopedRecords.filter {
            guard let end = $0.endedAt else { return false }
            return end >= today && $0.status != .inCorso && $0.status != .annullato
        }.count
        return (inProgressRecords.count, completedToday)
    }

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                DashboardEmptyStateView(state: .init(
                    title: "Seleziona un ristorante",
                    message: "Gli abbattimenti sono legati al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(theme.spacing.screenPadding)
            } else {
                mainScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Abbattimento")
        .haccpControlTint()
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            guard let rid = appState.activeRestaurantId else { return }
            dataStore.reload(context: modelContext, restaurantId: rid)
            RestaurantModuleBootstrap.shared.runOnce(restaurantId: rid, module: "blast-productions") {
                ensureProductions()
            }
        }
        .sheet(isPresented: $showNewSheet) {
            if currentUser != nil {
                BlastChillingNewSheet(
                    productions: scopedProductions,
                    categories: scopedCategories,
                    onContinue: { subject in
                        showNewSheet = false
                        pendingSubject = subject
                        recordToComplete = nil
                        vm.showRecordSheet = true
                    },
                    onCancel: { showNewSheet = false }
                )
            }
        }
        .sheet(isPresented: $vm.showRecordSheet) {
            if let user = currentUser,
               let rid = appState.activeRestaurantId {
                let subject = recordToComplete.map(subjectForRecord) ?? pendingSubject
                if let subject {
                    BlastChillingRecordSheet(
                        production: subject.pseudoProduction(restaurantId: rid),
                        existingRecord: recordToComplete,
                        operatorName: user.name,
                        validationService: BlastChillingValidationService(),
                        onCancel: {
                            vm.showRecordSheet = false
                            recordToComplete = nil
                            pendingSubject = nil
                        },
                        onStart: { startedAt, initial, target in
                            startRecord(
                                restaurantId: rid,
                                subject: subject,
                                user: user,
                                startedAt: startedAt,
                                initial: initial,
                                target: target
                            )
                        },
                        onComplete: { record, endedAt, final, notes, action in
                            completeRecord(
                                record,
                                endedAt: endedAt,
                                final: final,
                                notes: notes,
                                action: action
                            )
                        }
                    )
                }
            }
        }
        .alert("Abbattimento", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { labelDraft != nil },
            set: { if !$0 { labelDraft = nil } }
        )) {
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
    }

    private var mainScroll: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Abbattimento in negativo",
                    subtitle: "Registra temperature e tempi per ogni piatto del catalogo",
                    systemImage: "wind.snow",
                    help: ModuleHelpLibrary.sidebar(.blastChilling)
                )

                statsRow

                if canExecute {
                    PrimaryButton(title: "Nuovo abbattimento", icon: "plus.circle.fill") {
                        showNewSheet = true
                    }
                }

                SecondaryButton(title: "Gestisci catalogo piatti", icon: "fork.knife") {
                    appState.pendingSidebarNavigation = .productionCatalog
                }

                if !inProgressRecords.isEmpty {
                    SecondaryButton(title: "Termina abbattimento", icon: "checkmark.circle.fill") {
                        blastManager.showActiveListSheet = true
                    }
                }

                if inProgressRecords.isEmpty && filteredHistory.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun abbattimento registrato",
                        message: "Avvia un nuovo abbattimento scegliendo un piatto dal catalogo.",
                        actionTitle: canExecute ? "Nuovo abbattimento" : nil
                    )) {
                        showNewSheet = true
                    }
                } else {
                    inProgressCard
                    filtersCard
                    BlastChillingHistoryView(records: filteredHistory)
                }
            }
            .padding(theme.spacing.screenPadding)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "In corso",
                value: "\(stats.inProgress)",
                subtitle: "Da terminare",
                icon: "wind.snow",
                accent: theme.colorInfo
            )
            StatCard(
                title: "Completati",
                value: "\(stats.completedToday)",
                subtitle: "Oggi",
                icon: "checkmark.circle.fill",
                accent: theme.colorSuccess
            )
        }
    }

    private var inProgressCard: some View {
        DashboardCardView(title: "Abbattimenti in corso", subtitle: "\(inProgressRecords.count) attivi") {
            if inProgressRecords.isEmpty {
                Text("Nessun abbattimento in corso.")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(inProgressRecords) { record in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.productionNameSnapshot)
                                    .font(.headline)
                                    .foregroundStyle(theme.colorTextPrimary)
                                Text(recordSubtitle(record))
                                    .font(.caption)
                                    .foregroundStyle(theme.colorTextSecondary)
                                HStack(spacing: 6) {
                                    Image(systemName: "timer")
                                        .font(.caption2)
                                    LiveProcessDurationText(
                                        since: record.startedAt,
                                        font: .caption.weight(.semibold).monospacedDigit(),
                                        color: theme.colorInfo
                                    )
                                }
                                .foregroundStyle(theme.colorTextSecondary)
                            }
                            Spacer()
                            Button("Termina") {
                                recordToComplete = record
                                pendingSubject = subjectForRecord(record)
                                vm.showRecordSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.colorWarning)
                        }
                        .padding(10)
                        .background(theme.colorSurface)
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    private var filtersCard: some View {
        DashboardCardView(title: "Filtri storico") {
            HStack(spacing: 10) {
                Picker("Categoria", selection: Binding(
                    get: { vm.selectedHistoryCategoryId },
                    set: { vm.selectedHistoryCategoryId = $0 }
                )) {
                    Text("Tutte").tag(Optional<UUID>.none)
                    ForEach(scopedCategories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                .pickerStyle(.menu)

                Picker("Stato", selection: Binding(
                    get: { vm.selectedHistoryStatus },
                    set: { vm.selectedHistoryStatus = $0 }
                )) {
                    Text("Tutti").tag(Optional<BlastChillingStatus>.none)
                    ForEach(BlastChillingStatus.allCases) { status in
                        Text(status.label).tag(Optional(status))
                    }
                }
                .pickerStyle(.menu)

                Picker("Operatore", selection: $vm.selectedHistoryOperator) {
                    ForEach(operators, id: \.self) { op in
                        Text(op).tag(op)
                    }
                }
                .pickerStyle(.menu)

                DatePicker("Dal", selection: $vm.historyStartDate, displayedComponents: .date)
                DatePicker("Al", selection: $vm.historyEndDate, displayedComponents: .date)
            }
            .foregroundStyle(theme.colorTextPrimary)
        }
    }

    private func recordSubtitle(_ record: BlastChillingRecord) -> String {
        var parts = [record.productionCategorySnapshot]
        if let lot = record.lotNumberSnapshot, !lot.isEmpty {
            parts.append("Lotto \(lot)")
        }
        parts.append("Inizio \(record.startedAt.formatted(date: .abbreviated, time: .shortened))")
        parts.append(String(format: "%.1f °C", record.initialTemperature))
        return parts.joined(separator: " · ")
    }

    private func subjectForRecord(_ record: BlastChillingRecord) -> KitchenProcessSubject {
        KitchenProcessSubject(
            source: record.traceabilityItemId != nil ? .traceability : .production,
            traceabilityItemId: record.traceabilityItemId,
            productTemplateId: nil,
            productionId: record.productionId,
            productName: record.productionNameSnapshot,
            lotNumber: record.lotNumberSnapshot,
            categoryName: record.productionCategorySnapshot
        )
    }

    private func ensureProductions() {
        guard let rid = appState.activeRestaurantId else { return }
        libraryService.ensureDefaults(
            restaurantId: rid,
            modelContext: modelContext
        )
    }

    private func startRecord(
        restaurantId: UUID,
        subject: KitchenProcessSubject,
        user: LocalUser,
        startedAt: Date,
        initial: Double,
        target: Double
    ) {
        do {
            _ = try vm.service.startRecord(
                restaurantId: restaurantId,
                subject: subject,
                startedAt: startedAt,
                initialTemperature: initial,
                targetTemperature: target,
                user: user,
                modelContext: modelContext
            )
            vm.showRecordSheet = false
            pendingSubject = nil
            vm.historyEndDate = Date()
            blastManager.refresh(context: modelContext, restaurantId: restaurantId)
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    private func completeRecord(
        _ record: BlastChillingRecord,
        endedAt: Date,
        final: Double,
        notes: String?,
        action: String?
    ) {
        do {
            try vm.service.completeRecord(
                record,
                endedAt: endedAt,
                finalTemperature: final,
                notes: notes,
                correctiveAction: action,
                modelContext: modelContext
            )
            vm.showRecordSheet = false
            pendingSubject = nil
            recordToComplete = nil
            vm.historyEndDate = Date()
            blastManager.refresh(context: modelContext, restaurantId: record.restaurantId)
            if record.status == .conforme || record.status == .nonConforme {
                let draft = labelService.draft(from: record)
                if ProductionLabelLinkMatcher.existingLabel(for: draft, in: scopedLabels) == nil {
                    labelDraft = draft
                }
            }
        } catch {
            vm.errorMessage = error.localizedDescription
        }
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
