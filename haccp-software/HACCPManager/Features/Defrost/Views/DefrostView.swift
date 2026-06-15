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

    @StateObject private var vm = DefrostViewModel()
    @StateObject private var dataStore = DefrostDataStore()

    @State private var showNewSheet = false
    @State private var recordIdToComplete: UUID?
    @State private var recordPendingDelete: DefrostRecord?
    @State private var showMasterAuthDelete = false
    @State private var labelDraftAfterComplete: ProductionLabelDraft?
    @State private var errorMessage: String?

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var isMaster: Bool { currentUser?.role == .master }

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
        .task(id: appState.activeRestaurantId) {
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitchenProcessRecordsDidChange)) { _ in
            reload()
        }
        .sheet(isPresented: $showNewSheet) {
            if let rid = appState.activeRestaurantId, let user = currentUser {
                DefrostNewSheet(
                    restaurantId: rid,
                    user: user,
                    traceabilityRecords: dataStore.traceabilityRecords,
                    onSaved: {
                        showNewSheet = false
                        reload()
                    },
                    onCancel: { showNewSheet = false }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { recordIdToComplete != nil },
            set: { if !$0 { recordIdToComplete = nil } }
        )) {
            if let id = recordIdToComplete,
               let record = dataStore.records.first(where: { $0.id == id }),
               let user = currentUser {
                DefrostCompleteSheet(
                    record: record,
                    user: user,
                    criticalities: dataStore.criticalities,
                    elapsedNow: defrostManager.now,
                    onCompleted: {
                        recordIdToComplete = nil
                        bumpHistoryRangeToIncludeToday()
                        reload()
                    },
                    onCancel: { recordIdToComplete = nil }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { labelDraftAfterComplete != nil },
            set: { if !$0 { labelDraftAfterComplete = nil } }
        )) {
            if let draft = labelDraftAfterComplete,
               let rid = appState.activeRestaurantId,
               let user = currentUser {
                ProductionLabelEditorSheet(
                    mode: .create(draft),
                    restaurantId: rid,
                    user: user,
                    onSaved: { labelDraftAfterComplete = nil },
                    onCancel: { labelDraftAfterComplete = nil }
                )
            }
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
    }

    private var mainScroll: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                statsRow

                PrimaryButton(title: "Nuovo decongelamento", icon: "plus.circle.fill") {
                    showNewSheet = true
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
                                        elapsedNow: defrostManager.now,
                                        onComplete: { recordIdToComplete = record.id }
                                    )
                                    if isMaster {
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
                if record.endAt != nil {
                    CreateProductionLabelLink {
                        labelDraftAfterComplete = ProductionLabelsService().draft(from: record)
                    }
                }
                if isMaster {
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
        let lot = record.lotNumber.map { "Lotto \($0) · " } ?? ""
        let fine = record.endAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"
        return "\(lot)\(record.method) · Durata \(record.durationText) · Fine \(fine) · \(record.createdByNameSnapshot)"
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

    private func reload() {
        dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
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
}
