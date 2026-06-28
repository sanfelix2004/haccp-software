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
    @StateObject private var dataStore = ChecklistDataStore()
    @StateObject private var historyVM = ChecklistHistoryViewModel()
    @State private var selectedRunForSheet: ChecklistRun?
    @State private var showRunSheet = false
    @State private var templateToEdit: ChecklistTemplate?
    @State private var showEditTemplateSheet = false
    @State private var masterAuth = MasterAuthCoordinator()

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
                reloadChecklistData()
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }

    var body: some View {
        Group {
            if restaurantId == nil {
                emptyRestaurant
            } else if dataStore.isLoading && dataStore.runs.isEmpty && dataStore.templates.isEmpty {
                loadingState
            } else {
                mainContent
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Checklist")
        .haccpControlTint()
        .moduleHelpToolbar(ModuleHelpLibrary.sidebar(.checklist))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        masterAuth.request(permission: .manageChecklistTemplates, permissions: permissions) {
                            vm.showQuickTaskSheet = true
                        }
                    } label: {
                        Label("Attività rapida", systemImage: "bolt.circle")
                    }
                    Button {
                        masterAuth.request(permission: .manageChecklistTemplates, permissions: permissions) {
                            vm.showCreateTemplate = true
                        }
                    } label: {
                        Label("Nuovo modello", systemImage: "plus.rectangle.on.folder")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
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
                            vm.selectedTab = .alerts
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $vm.showCreateTemplate, onDismiss: reloadChecklistData) {
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
                        syncScheduledChecklistState()
                    },
                    onCancel: { vm.showQuickTaskSheet = false }
                )
            }
        }
        .sheet(isPresented: $showEditTemplateSheet, onDismiss: reloadChecklistData) {
            if let templateToEdit {
                EditChecklistTemplateView(template: templateToEdit, service: vm.service)
            }
        }
        .onChange(of: showRunSheet) { _, isShown in
            if !isShown {
                syncScheduledChecklistState()
            }
        }
        .alert("Checklist", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .task(id: restaurantId) {
            reloadChecklistData()
            SchedulingToChecklistMigrationService.migrateIfNeeded(modelContext: modelContext)
            syncScheduledChecklistState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitchenProcessRecordsDidChange)) { _ in
            reloadChecklistData()
        }
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

    private var mainContent: some View {
        VStack(spacing: theme.spacing.sectionSpacing) {
            Picker("Sezione checklist", selection: $vm.selectedTab) {
                ForEach(ChecklistTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, theme.spacing.screenPadding)

            Group {
                switch vm.selectedTab {
                case .dashboard:
                    ChecklistDashboardView(
                        runs: operationalRuns,
                        templates: scopedTemplates,
                        itemResults: dataStore.itemResults,
                        counts: vm.dashboardCounts(runs: operationalRuns, templates: scopedTemplates),
                        onCreateTemplate: { requestCreateTemplate() },
                        onCreateQuickTask: { requestQuickTask() },
                        canCreate: true,
                        onOpenRun: openRun,
                        onGoToTemplates: { vm.selectedTab = .templates }
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
                        vm: historyVM
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
        }
    }

    private func reloadChecklistData() {
        dataStore.reload(context: modelContext, restaurantId: restaurantId)
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
            reloadChecklistData()
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
        reloadChecklistData()
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
            reloadChecklistData()
            openRun(run)
        } catch {
            vm.errorMessage = "Avvio checklist non riuscito."
        }
    }

    private func syncScheduledChecklistState() {
        guard let restaurantId else { return }
        vm.service.syncScheduledRuns(
            restaurantId: restaurantId,
            user: currentUser,
            modelContext: modelContext
        )
        reloadChecklistData()
    }
}
