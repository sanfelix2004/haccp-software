import SwiftUI
import SwiftData
import Combine

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]

    @StateObject private var vm = ChecklistViewModel()
    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.checklist
    @StateObject private var historyVM = ChecklistHistoryViewModel()
    @State private var selectedRunForSheet: ChecklistRun?
    @State private var showRunSheet = false
    @State private var templateToEdit: ChecklistTemplate?
    @State private var showEditTemplateSheet = false
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var syncTask: Task<Void, Never>?

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }
    private var restaurantId: UUID? {
        appState.activeRestaurantId ?? restaurants.first?.id
    }
    private var scopedTemplates: [ChecklistTemplate] {
        guard restaurantId != nil else { return [] }
        return dataStore.templates.filter {
            !$0.isSuggestedLibrary
                && !$0.isCleaningBridge
                && $0.category != .cleaning
        }
    }

    private var operationalTemplateIds: Set<UUID> {
        Set(scopedTemplates.map(\.id))
    }

    private var operationalRuns: [ChecklistRun] {
        scopedRuns.filter { operationalTemplateIds.contains($0.templateId) }
    }

    private var operationalAlerts: [ChecklistAlert] {
        let runIds = Set(operationalRuns.map(\.id))
        return scopedAlerts.filter { runIds.contains($0.checklistRunId) }
    }

    private var scopedRuns: [ChecklistRun] {
        dataStore.runs
    }

    private var scopedAlerts: [ChecklistAlert] {
        dataStore.alerts
    }

    private var scopedCleaningCriticalities: [CleaningCriticality] {
        dataStore.cleaningCriticalities
    }

    private var permissions: UserPermissions { currentUser.permissions }

    private var canExecuteChecklists: Bool {
        permissions.canPerform(.executeRecords)
    }

    private var pendingCount: Int {
        let counts = vm.dashboardCounts(runs: operationalRuns, templates: scopedTemplates)
        return counts.todo + counts.inProgress
    }

    private var openCriticalitiesCount: Int {
        guard let restaurantId else { return 0 }
        return UnifiedCriticalityQuery.allOpen(
            checklistAlerts: operationalAlerts,
            cleaningCriticalities: scopedCleaningCriticalities,
            restaurantId: restaurantId
        ).count
    }

    private var navigationSubtitle: String {
        switch vm.selectedTab {
        case .dashboard:
            return pendingCount > 0 ? "\(pendingCount) da fare" : "Aggiornato"
        case .templates:
            return "\(scopedTemplates.count) modelli"
        case .history:
            return "Ultimi 30 giorni"
        case .alerts:
            return openCriticalitiesCount > 0
                ? "\(openCriticalitiesCount) da risolvere"
                : "Nessuna aperta"
        }
    }

    private func requestCreateTemplate() {
        masterAuth.request(permission: .manageChecklistTemplates, permissions: permissions) {
            vm.showCreateTemplate = true
        }
    }

    private func requestQuickTask() {
        masterAuth.request(permission: .manageChecklistTemplates, permissions: permissions) {
            vm.showQuickTaskSheet = true
        }
    }

    private func requestEditTemplate(_ template: ChecklistTemplate) {
        masterAuth.request(permission: .manageChecklistTemplates, permissions: permissions) {
            templateToEdit = template
            showEditTemplateSheet = true
        }
    }

    private func requestDeleteTemplate(_ template: ChecklistTemplate) {
        masterAuth.request(permission: .manageChecklistTemplates, permissions: permissions) {
            guard let currentUser else { return }
            do {
                try vm.service.deleteTemplate(template, user: currentUser, modelContext: modelContext)
                reloadChecklistData(force: true)
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }

    var body: some View {
        Group {
            if restaurantId == nil {
                emptyRestaurant
            } else if dataStore.isLoading && operationalRuns.isEmpty && scopedTemplates.isEmpty {
                loadingState
            } else {
                tabbedContent
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Checklist")
        .navigationSubtitle(navigationSubtitle)
        .haccpControlTint()
        .moduleHelpToolbar(ModuleHelpLibrary.sidebar(.checklist))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    requestQuickTask()
                } label: {
                    Label("Attività rapida", systemImage: "bolt.circle")
                }
                Button {
                    requestCreateTemplate()
                } label: {
                    Label("Nuovo modello", systemImage: "plus")
                }
            }
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
        .sheet(isPresented: $showRunSheet) {
            if let selectedRunForSheet {
                NavigationStack {
                    ChecklistRunView(
                        run: selectedRunForSheet,
                        service: vm.service,
                        onOpenCriticalities: {
                            showRunSheet = false
                            vm.selectedTab = .alerts
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $vm.showCreateTemplate, onDismiss: { reloadChecklistData(force: true) }) {
            CreateChecklistTemplateView(service: vm.service)
        }
        .sheet(isPresented: $vm.showQuickTaskSheet) {
            if let restaurantId, let currentUser {
                ChecklistQuickTaskSheet(
                    restaurantId: restaurantId,
                    user: currentUser,
                    service: vm.service,
                    onSaved: {
                        vm.showQuickTaskSheet = false
                        scheduleDeferredSync(forceReload: true)
                    },
                    onCancel: { vm.showQuickTaskSheet = false }
                )
            }
        }
        .sheet(isPresented: $showEditTemplateSheet, onDismiss: { reloadChecklistData(force: true) }) {
            if let templateToEdit {
                EditChecklistTemplateView(template: templateToEdit, service: vm.service)
            }
        }
        .onChange(of: showRunSheet) { _, isShown in
            if !isShown {
                scheduleDeferredSync(forceReload: true)
            }
        }
        .alert("Checklist", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            guard let restaurantId else { return }
            await dataStore.reloadAndWait(context: modelContext, restaurantId: restaurantId)
            scheduleDeferredSync()
        }
        .task(id: restaurantId) {
            guard let restaurantId else { return }
            RestaurantModuleBootstrap.shared.runOnce(restaurantId: restaurantId, module: "checklist-migrate") {
                SchedulingToChecklistMigrationService.migrateIfNeeded(modelContext: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitchenProcessRecordsDidChange)) { _ in
            reloadChecklistData(force: true)
        }
        .onDisappear {
            syncTask?.cancel()
        }
    }

    private var tabbedContent: some View {
        VStack(spacing: theme.spacing.sectionSpacing) {
            Picker("Sezione checklist", selection: $vm.selectedTab) {
                ForEach(ChecklistTab.allCases) { tab in
                    Text(tabPickerLabel(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Sezione checklist")

            Group {
                switch vm.selectedTab {
                case .dashboard:
                    ChecklistDashboardView(
                        runs: operationalRuns,
                        templates: scopedTemplates,
                        itemResults: dataStore.itemResults,
                        counts: vm.dashboardCounts(runs: operationalRuns, templates: scopedTemplates),
                        isRefreshing: dataStore.isLoading,
                        service: vm.service,
                        user: currentUser,
                        canExecute: canExecuteChecklists,
                        onCreateTemplate: { requestCreateTemplate() },
                        onCreateQuickTask: { requestQuickTask() },
                        canCreate: true,
                        onOpenRun: openRun,
                        onBrowseTemplates: { vm.selectedTab = .templates },
                        onDataChanged: { reloadChecklistData(force: true) }
                    )
                case .templates:
                    ChecklistTemplatesView(
                        templates: scopedTemplates,
                        canManage: true,
                        canExecute: canExecuteChecklists,
                        onCreate: { requestCreateTemplate() },
                        onStartRun: startRun,
                        onEdit: { requestEditTemplate($0) },
                        onDelete: { requestDeleteTemplate($0) },
                        currentRole: currentUser?.role
                    )
                case .history:
                    ChecklistHistoryView(
                        runs: operationalRuns,
                        templates: scopedTemplates,
                        vm: historyVM,
                        onOpenRun: openRun
                    )
                case .alerts:
                    UnifiedCriticalitiesView(
                        checklistAlerts: operationalAlerts,
                        cleaningCriticalities: scopedCleaningCriticalities,
                        onResolveChecklist: resolveAlert,
                        onResolveCleaning: resolveCleaningCriticality
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(theme.motion.standard, value: vm.selectedTab)
        }
        .padding(theme.spacing.screenPadding)
    }

    private func tabPickerLabel(_ tab: ChecklistTab) -> String {
        if tab == .alerts, openCriticalitiesCount > 0 {
            return "Criticità (\(openCriticalitiesCount))"
        }
        return tab.rawValue
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Caricamento checklist…")
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyRestaurant: some View {
        DashboardEmptyStateView(state: .init(
            title: "Seleziona un ristorante",
            message: "Le checklist operative sono legate al ristorante attivo.",
            actionTitle: nil
        ))
        .padding(theme.spacing.screenPadding)
    }

    private func reloadChecklistData(force: Bool = false) {
        dataStore.reload(context: modelContext, restaurantId: restaurantId, force: force)
    }

    private func openRun(_ run: ChecklistRun) {
        selectedRunForSheet = run
        showRunSheet = true
    }

    private func resolveAlert(_ alert: ChecklistAlert, correctiveAction: String) {
        guard let currentUser else { return }
        do {
            try vm.service.resolveAlert(
                alert,
                correctiveAction: correctiveAction,
                user: currentUser,
                modelContext: modelContext
            )
            reloadChecklistData(force: true)
        } catch {
            vm.errorMessage = "Risoluzione criticità non riuscita."
        }
    }

    private func resolveCleaningCriticality(_ criticality: CleaningCriticality, correctiveAction: String) {
        guard let currentUser else { return }
        criticality.isResolved = true
        criticality.correctiveAction = correctiveAction
        criticality.resolvedAt = Date()
        criticality.resolvedByUserId = currentUser.id
        criticality.resolvedByNameSnapshot = currentUser.name
        if !modelContext.saveSafely(operation: "cleaning-criticality-resolve") {
            vm.errorMessage = "Salvataggio criticità non riuscito."
            return
        }
        reloadChecklistData(force: true)
    }

    private func startRun(from template: ChecklistTemplate) {
        guard let restaurantId, let user = currentUser else {
            vm.errorMessage = "Seleziona un ristorante e accedi per avviare una checklist."
            return
        }
        do {
            let run = try vm.service.startRun(
                template: template,
                user: user,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
            reloadChecklistData(force: true)
            vm.selectedTab = .dashboard
            openRun(run)
        } catch {
            vm.errorMessage = "Avvio checklist non riuscito."
        }
    }

    private func scheduleDeferredSync(forceReload: Bool = false) {
        syncTask?.cancel()
        syncTask = Task(priority: .utility) { @MainActor in
            await MainThreadYield.afterNavigation()
            await MainThreadYield.afterNavigation()
            guard !Task.isCancelled, let restaurantId else { return }

            if !forceReload {
                guard RestaurantModuleBootstrap.shared.claimOnce(
                    restaurantId: restaurantId,
                    module: "checklist-period-sync"
                ) else { return }
            }

            vm.service.syncScheduledRuns(
                restaurantId: restaurantId,
                user: currentUser,
                modelContext: modelContext
            )
            guard !Task.isCancelled else { return }
            reloadChecklistData(force: true)
        }
    }
}
