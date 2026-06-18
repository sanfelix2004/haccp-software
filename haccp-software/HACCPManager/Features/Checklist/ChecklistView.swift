import SwiftUI
import SwiftData
import Combine

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var templates: [ChecklistTemplate]
    @Query private var runs: [ChecklistRun]
    @Query private var itemResults: [ChecklistItemResult]
    @Query private var alerts: [ChecklistAlert]

    @StateObject private var vm = ChecklistViewModel()
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
        guard let restaurantId else { return [] }
        return templates.filter { $0.restaurantId == restaurantId && !$0.isSuggestedLibrary }
    }

    private var scopedRuns: [ChecklistRun] {
        guard let restaurantId else { return [] }
        return runs.filter { $0.restaurantId == restaurantId && !$0.isArchived }
    }

    private var scopedAlerts: [ChecklistAlert] {
        guard let restaurantId else { return [] }
        return alerts.filter { $0.restaurantId == restaurantId }
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
            modelContext.delete(template)
            try? modelContext.save()
        }
    }

    var body: some View {
        Group {
            if restaurantId == nil {
                emptyRestaurant
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
                    ChecklistRunView(run: selectedRunForSheet, service: vm.service)
                }
            }
        }
        .sheet(isPresented: $vm.showCreateTemplate) {
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
        .sheet(isPresented: $showEditTemplateSheet) {
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
        .onAppear {
            SchedulingToChecklistMigrationService.migrateIfNeeded(modelContext: modelContext)
            syncScheduledChecklistState()
        }
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
                        runs: scopedRuns,
                        templates: scopedTemplates,
                        itemResults: itemResults,
                        alerts: scopedAlerts,
                        counts: vm.dashboardCounts(runs: scopedRuns, alerts: scopedAlerts),
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
                        runs: scopedRuns,
                        templates: scopedTemplates,
                        vm: historyVM
                    )
                case .alerts:
                    ChecklistAlertsView(
                        alerts: scopedAlerts,
                        onResolve: resolveAlert
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
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
        } catch {
            vm.errorMessage = "Risoluzione criticità non riuscita."
        }
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
    }
}
