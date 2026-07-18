//
//  DefrostView.swift
//  Modulo decongelamento — semplice e professionale per cucina.
//

import SwiftUI
import SwiftData

struct DefrostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var defrostManager: ActiveDefrostManager

    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var productTemplates: [ProductTemplate]
    @Query private var productionLabels: [ProductionLabelRecord]

    @StateObject private var vm = DefrostViewModel()
    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.defrost

    @State private var showNewSheet = false
    @State private var recordIdToComplete: UUID?
    @State private var recordPendingDelete: DefrostRecord?
    @State private var pendingSubject: KitchenProcessSubject?
    @State private var showStartProcessSheet = false
    @State private var showMasterAuthDelete = false
    @State private var errorMessage: String?
    @State private var labelDraft: ProductionLabelDraft?

    private let labelService = ProductionLabelsService()

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

    private var permissions: UserPermissions { currentUser.permissions }
    private var canDeleteRecords: Bool { permissions.can(.deleteOperationalRecords) }
    private var canExecute: Bool { permissions.can(.executeRecords) }

    private var scopedTemplates: [ProductTemplate] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return productTemplates.filter { $0.restaurantId == rid }
    }

    private var stats: (inProgress: Int, completedToday: Int) {
        vm.stats(from: dataStore.records)
    }

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                DashboardEmptyStateView(state: .init(
                    title: "Seleziona un ristorante",
                    message: "I decongelamenti sono legati al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(24)
            } else if dataStore.isLoading && dataStore.records.isEmpty {
                ProgressView("Caricamento…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Decongelamento")
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            guard let rid = appState.activeRestaurantId else { return }
            ensureTemplates(restaurantId: rid)
            dataStore.reload(context: modelContext, restaurantId: rid)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitchenProcessRecordsDidChange)) { _ in
            reload(force: true)
            defrostManager.refresh(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
        .sheet(isPresented: $showNewSheet) {
            newDefrostSheet
        }
        .sheet(isPresented: $showStartProcessSheet) {
            startDefrostProcessSheet
        }
        .sheet(isPresented: completeSheetPresented) {
            completeDefrostSheet
        }
        .fullScreenCover(isPresented: $showMasterAuthDelete) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .privilegedAction,
                    onAuthorized: {
                        showMasterAuthDelete = false
                        if let record = recordPendingDelete {
                            deleteRecord(record)
                        }
                        recordPendingDelete = nil
                    },
                    onCancel: {
                        showMasterAuthDelete = false
                        recordPendingDelete = nil
                    }
                ) { EmptyView() }
            }
        }
        .alert("Decongelamento", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: labelEditorPresented) {
            labelEditorSheet
        }
    }

    private var completeSheetPresented: Binding<Bool> {
        Binding(
            get: { recordIdToComplete != nil },
            set: { if !$0 { recordIdToComplete = nil } }
        )
    }

    private var labelEditorPresented: Binding<Bool> {
        Binding(
            get: { labelDraft != nil },
            set: { if !$0 { labelDraft = nil } }
        )
    }

    @ViewBuilder
    private var newDefrostSheet: some View {
        if let rid = appState.activeRestaurantId, let user = currentUser {
            DefrostNewSheet(
                restaurantId: rid,
                user: user,
                traceabilityRecords: dataStore.traceabilityRecords,
                incomingFoodTemplates: scopedTemplates,
                onContinue: { subject in
                    showNewSheet = false
                    pendingSubject = subject
                    showStartProcessSheet = true
                },
                onCancel: { showNewSheet = false }
            )
        }
    }

    @ViewBuilder
    private var startDefrostProcessSheet: some View {
        if let subject = pendingSubject,
           let rid = appState.activeRestaurantId,
           let user = currentUser {
            DefrostStartProcessSheet(
                subject: subject,
                restaurantId: rid,
                user: user,
                onSaved: {
                    showStartProcessSheet = false
                    pendingSubject = nil
                    reload()
                },
                onCancel: {
                    showStartProcessSheet = false
                    pendingSubject = nil
                }
            )
        }
    }

    @ViewBuilder
    private var completeDefrostSheet: some View {
        if let id = recordIdToComplete,
           let record = dataStore.records.first(where: { $0.id == id }),
           let user = currentUser {
            DefrostCompleteSheet(
                record: record,
                user: user,
                criticalities: dataStore.criticalities,
                onCompleted: { handleDefrostCompleted(record) },
                onCancel: { recordIdToComplete = nil }
            )
        }
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

    private func handleDefrostCompleted(_ record: DefrostRecord) {
        recordIdToComplete = nil
        bumpHistoryRangeToIncludeToday()
        reload()
        if record.defrostStatus == .completed || record.defrostStatus == .completedWithCriticality {
            let draft = labelService.draft(from: record)
            if ProductionLabelLinkMatcher.existingLabel(for: draft, in: scopedLabels) == nil {
                labelDraft = draft
            }
        }
    }

    private var mainScroll: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Decongelamento",
                    subtitle: "Traccia prodotti, metodi e tempi in cucina",
                    systemImage: "snowflake",
                    help: ModuleHelpLibrary.sidebar(.defrost)
                )

                statsRow

                PrimaryButton(title: "Nuovo decongelamento", icon: "plus.circle.fill") {
                    showNewSheet = true
                }

                SecondaryButton(title: "Gestisci alimenti in ingresso", icon: "tray.full.fill") {
                    appState.pendingSidebarNavigation = .incomingFoodCatalog
                }

                let active = vm.activeRecords(from: dataStore.records)
                if !active.isEmpty {
                    SecondaryButton(title: "Termina decongelamento", icon: "checkmark.circle.fill") {
                        defrostManager.showActiveListSheet = true
                    }
                }

                if active.isEmpty && vm.historyRecords(from: dataStore.records).isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun decongelamento registrato",
                        message: "Avvia un nuovo decongelamento per tracciare prodotto, metodo e tempi in cucina.",
                        actionTitle: "Nuovo decongelamento"
                    )) {
                        showNewSheet = true
                    }
                } else {
                    if !active.isEmpty {
                        DashboardCardView(title: "In corso", subtitle: "\(active.count) processi attivi") {
                            LazyVStack(spacing: 12) {
                                ForEach(active) { record in
                                    DefrostRecordCardView(
                                        record: record,
                                        showCompleteAction: true,
                                        onComplete: { recordIdToComplete = record.id }
                                    )
                                    if canDeleteRecords {
                                        Button("Annulla processo", role: .destructive) {
                                            cancelRecord(record)
                                        }
                                        .font(theme.typography.caption)
                                    }
                                }
                            }
                        }
                    }

                    DashboardCardView(title: "Storico", subtitle: "Decongelamenti completati o annullati") {
                        DefrostHistoryFilterBar(filter: $vm.historyFilter, records: dataStore.records)
                        let history = vm.historyRecords(from: dataStore.records)
                        if history.isEmpty {
                            Text("Nessun record nello storico per i filtri selezionati.")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colorTextSecondary)
                                .padding(.top, 8)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(history.prefix(60)) { record in
                                    historyRow(record)
                                }
                            }
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "In corso",
                value: "\(stats.inProgress)",
                subtitle: "Da terminare",
                icon: "snowflake",
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

    private func historyRow(_ record: DefrostRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.productName)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Spacer()
                HACCPBadge(title: record.historyStatusLabel, style: badgeStyle(for: record), showIcon: false)
            }
            Text(historySubtitle(record))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            HStack(spacing: 12) {
                if canDeleteRecords {
                    Button("Elimina", role: .destructive) {
                        recordPendingDelete = record
                        showMasterAuthDelete = true
                    }
                    .font(theme.typography.caption)
                }
                if let crit = vm.service.openCriticality(for: record.id, in: dataStore.criticalities), !crit.isResolved {
                    Button("Risolvi criticità") {
                        resolveCriticality(crit)
                    }
                    .font(theme.typography.caption)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
    }

    private func historySubtitle(_ record: DefrostRecord) -> String {
        let category = record.categoryNameSnapshot.map { "\($0) · " } ?? ""
        let lot = record.lotNumber.map { "Lotto \($0) · " } ?? ""
        let fine = record.endAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"
        return "\(category)\(lot)\(record.method) · Durata \(record.durationText) · Fine \(fine) · \(record.createdByNameSnapshot)"
    }

    private func badgeStyle(for record: DefrostRecord) -> HACCPBadgeStyle {
        let status: DefrostStatus = {
            if record.endAt != nil, let stored = DefrostStatus(rawValue: record.statusRaw) {
                return stored
            }
            return record.displayStatus()
        }()
        switch status {
        case .completed: return .conforme
        case .completedWithCriticality: return .nonConforme
        case .delayed: return .warning
        case .cancelled: return .neutral
        case .inProgress: return .info
        }
    }

    private func reload(force: Bool = false) {
        dataStore.reload(
            context: modelContext,
            restaurantId: appState.activeRestaurantId,
            force: force
        )
        defrostManager.refresh(context: modelContext, restaurantId: appState.activeRestaurantId)
    }

    private func bumpHistoryRangeToIncludeToday() {
        let today = Date()
        if vm.historyFilter.endDate < today {
            vm.historyFilter.endDate = today
        }
    }

    private func cancelRecord(_ record: DefrostRecord) {
        do {
            try vm.service.cancelDefrost(record, modelContext: modelContext)
            bumpHistoryRangeToIncludeToday()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRecord(_ record: DefrostRecord) {
        do {
            try vm.service.deleteDefrost(record, criticalities: dataStore.criticalities, modelContext: modelContext)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveCriticality(_ criticality: DefrostCriticality) {
        guard let user = currentUser else { return }
        do {
            try vm.service.resolveCriticality(criticality, user: user, modelContext: modelContext)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureTemplates(restaurantId rid: UUID) {
        RestaurantModuleBootstrap.shared.runOnce(restaurantId: rid, module: "defrost-templates") {
            ProductTemplateSeeder.ensureTemplates(restaurantId: rid, modelContext: modelContext)
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
