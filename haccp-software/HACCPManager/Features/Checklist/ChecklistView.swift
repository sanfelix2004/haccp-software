import SwiftUI
import SwiftData
import Combine

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var templates: [ChecklistTemplate]
    @Query private var runs: [ChecklistRun]
    @Query private var itemResults: [ChecklistItemResult]
    @Query private var alerts: [ChecklistAlert]

    @StateObject private var vm = ChecklistViewModel()
    @State private var selectedRunForSheet: ChecklistRun?
    @State private var showRunSheet = false
    @State private var templateToEdit: ChecklistTemplate?
    @State private var showEditTemplateSheet = false

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

    private var canManageTemplates: Bool {
        currentUser?.role == .master
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Sezione checklist", selection: $vm.selectedTab) {
                ForEach(ChecklistTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch vm.selectedTab {
                case .dashboard:
                    ChecklistDashboardView(
                        runs: scopedRuns,
                        templates: scopedTemplates,
                        itemResults: itemResults,
                        alerts: scopedAlerts,
                        counts: vm.dashboardCounts(runs: scopedRuns, alerts: scopedAlerts),
                        onCreateTemplate: { vm.showCreateTemplate = true },
                        canCreate: canManageTemplates,
                        onOpenRun: { run in
                            selectedRunForSheet = run
                            showRunSheet = true
                        }
                    )
                case .templates:
                    ChecklistTemplatesView(
                        templates: scopedTemplates,
                        canManage: canManageTemplates,
                        canExecute: false,
                        onCreate: { vm.showCreateTemplate = true },
                        onStartRun: { _ in },
                        onEdit: { template in
                            templateToEdit = template
                            showEditTemplateSheet = true
                        },
                        onDelete: { template in
                            modelContext.delete(template)
                            try? modelContext.save()
                        },
                        currentRole: currentUser?.role
                    )
                case .alerts:
                    ChecklistAlertsView(
                        alerts: scopedAlerts,
                        onResolve: { alert, action in
                            resolveAlert(alert, correctiveAction: action)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(24)
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Checklist")
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
            syncScheduledChecklistState()
        }
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
            vm.errorMessage = "Risoluzione alert non riuscita."
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
