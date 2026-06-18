import SwiftUI
import SwiftData

struct OilControlView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var points: [OilPoint]
    @Query private var records: [OilControlRecord]
    @Query private var alerts: [OilControlAlert]
    @StateObject private var vm = OilControlViewModel()
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var pendingMasterAction: MasterAction?
    @State private var recordPendingDeletion: OilControlRecord?

    private enum MasterAction {
        case addPoint
        case editPoint
        case deletePoint
        case deleteRecord
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var permissions: UserPermissions { currentUser.permissions }
    private var canManagePoints: Bool { permissions.can(.manageOilControlPoints) }
    private var canDeleteRecords: Bool { permissions.can(.deleteOperationalRecords) }
    private var canExecute: Bool { permissions.can(.executeRecords) }

    private var scopedPoints: [OilPoint] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return points
            .filter { $0.restaurantId == rid && $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var scopedRecords: [OilControlRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    private var scopedAlerts: [OilControlAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return alerts.filter { $0.restaurantId == rid }
    }

    private var filteredHistory: [OilControlRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: vm.historyStartDate)
        let endStart = calendar.startOfDay(for: vm.historyEndDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? vm.historyEndDate
        return scopedRecords.filter { record in
            let periodOk = record.checkedAt >= start && record.checkedAt <= end
            let pointOk = vm.selectedHistoryPointId == nil || record.oilPointId == vm.selectedHistoryPointId
            let statusOk = vm.selectedHistoryStatus == nil || record.oilStatus == vm.selectedHistoryStatus
            let operatorOk = vm.selectedHistoryOperator == "Tutti" || record.createdByNameSnapshot == vm.selectedHistoryOperator
            return periodOk && pointOk && statusOk && operatorOk
        }
    }

    private var operators: [String] {
        ["Tutti"] + Array(Set(scopedRecords.map(\.createdByNameSnapshot))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ModuleScreenHeader(
                    title: "Controllo olio",
                    subtitle: "Polarità, sostituzione olio e storico friggitrici",
                    systemImage: "drop.fill",
                    help: ModuleHelpLibrary.sidebar(.oilControl)
                )

                DashboardCardView(title: "Punti olio", subtitle: "Seleziona e registra un controllo", help: ModuleHelpLibrary.sidebar(.oilControl)) {
                    VStack(spacing: 14) {
                        headerMetrics
                        if scopedPoints.isEmpty {
                            DashboardEmptyStateView(state: .init(
                                title: "Nessun punto olio configurato",
                                message: "Il MASTER può aggiungere friggitrici e punti olio.",
                                actionTitle: nil
                            ))
                        } else {
                            OilPointGridView(
                                points: scopedPoints,
                                records: scopedRecords,
                                selectedPointId: vm.selectedPoint?.id,
                                onSelect: { vm.selectedPoint = $0 }
                            )
                        }
                        actionBar
                    }
                }

                filtersCard
                OilHistoryView(records: filteredHistory, canDelete: canDeleteRecords) { record in
                    recordPendingDeletion = record
                    pendingMasterAction = .deleteRecord
                    performPrivilegedAction()
                }
            }
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Controllo olio")
        .onAppear { ensureDefaults() }
        .onChange(of: appState.activeRestaurantId) { _, _ in ensureDefaults() }
        .sheet(isPresented: $vm.showCheckSheet) {
            if let point = vm.selectedPoint,
               let rid = appState.activeRestaurantId,
               let user = currentUser {
                OilCheckSheet(
                    point: point,
                    restaurantId: rid,
                    user: user,
                    service: vm.service,
                    onSaved: {
                        vm.historyEndDate = Date()
                    }
                )
            }
        }
        .sheet(isPresented: $vm.showPointEditor) {
            pointEditor
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
        .alert("Controllo olio", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var headerMetrics: some View {
        let activeAlerts = scopedAlerts.filter { $0.isActive }.count
        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Punti olio",
                value: "\(scopedPoints.count)",
                icon: "drop.fill",
                accent: ThemeManager.shared.colorInfo
            )
            StatCard(
                title: "Controlli",
                value: "\(scopedRecords.count)",
                icon: "checklist",
                accent: ThemeManager.shared.colorPrimary
            )
            StatCard(
                title: "Alert attivi",
                value: "\(activeAlerts)",
                subtitle: activeAlerts > 0 ? "Da gestire" : "Nessuno",
                icon: "exclamationmark.triangle.fill",
                accent: activeAlerts > 0 ? ThemeManager.shared.colorWarning : ThemeManager.shared.colorTextSecondary
            )
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Aggiungi") {
                    masterAuth.request(permission: .manageOilControlPoints, permissions: permissions) {
                        vm.pointToEdit = nil
                        vm.newPointName = ""
                        vm.showPointEditor = true
                    }
                }
                .buttonStyle(.bordered)
                .tint(ThemeManager.shared.colorPrimary)

                Button("Modifica") {
                    guard let selected = vm.selectedPoint else {
                        vm.errorMessage = "Seleziona un punto olio da modificare."
                        return
                    }
                    masterAuth.request(permission: .manageOilControlPoints, permissions: permissions) {
                        vm.pointToEdit = selected
                        vm.newPointName = selected.name
                        vm.showPointEditor = true
                    }
                }
                .buttonStyle(.bordered)
                .tint(ThemeManager.shared.colorPrimary)
                .disabled(vm.selectedPoint == nil)

                Button("Elimina", role: .destructive) {
                    guard vm.selectedPoint != nil else { return }
                    pendingMasterAction = .deletePoint
                    performPrivilegedAction()
                }
                .buttonStyle(.bordered)
                .disabled(vm.selectedPoint == nil)

            Spacer()

                Button("Inserisci controllo") {
                    masterAuth.request(permission: .executeRecords, permissions: permissions) {
                        vm.showCheckSheet = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.selectedPoint == nil ? ThemeManager.shared.colorTextSecondary : ThemeManager.shared.colorSuccess)
                .disabled(vm.selectedPoint == nil)
        }
    }

    private var filtersCard: some View {
        DashboardCardView(title: "Filtri storico controllo olio") {
            HStack(spacing: 10) {
                DatePicker("Dal", selection: $vm.historyStartDate, displayedComponents: .date)
                DatePicker("Al", selection: $vm.historyEndDate, displayedComponents: .date)
                Picker("Punto olio", selection: Binding(
                    get: { vm.selectedHistoryPointId },
                    set: { vm.selectedHistoryPointId = $0 }
                )) {
                    Text("Tutti").tag(Optional<UUID>.none)
                    ForEach(scopedPoints) { point in
                        Text(point.name).tag(Optional(point.id))
                    }
                }
                .pickerStyle(.menu)
                Picker("Stato", selection: Binding(
                    get: { vm.selectedHistoryStatus },
                    set: { vm.selectedHistoryStatus = $0 }
                )) {
                    Text("Tutti").tag(Optional<OilStatus>.none)
                    ForEach(OilStatus.allCases) { status in
                        Text(status.label).tag(Optional(status))
                    }
                }
                .pickerStyle(.menu)
                Picker("Operatore", selection: $vm.selectedHistoryOperator) {
                    ForEach(operators, id: \.self) { operatorName in
                        Text(operatorName).tag(operatorName)
                    }
                }
                .pickerStyle(.menu)
            }
            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
        }
    }

    private var pointEditor: some View {
        NavigationStack {
            Form {
                Section(vm.pointToEdit == nil ? "Nuovo punto olio" : "Modifica punto olio") {
                    TextField("Nome punto olio", text: $vm.newPointName)
                }
            }
            .navigationTitle(vm.pointToEdit == nil ? "Nuovo punto olio" : "Modifica punto olio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { vm.showPointEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { savePoint() }
                        .disabled(vm.newPointName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func ensureDefaults() {
        guard let rid = appState.activeRestaurantId, let user = currentUser else { return }
        vm.service.ensureDefaultPoints(
            restaurantId: rid,
            user: user,
            existingPoints: points,
            modelContext: modelContext
        )
    }

    private func performPrivilegedAction() {
        guard let action = pendingMasterAction else { return }
        let permission: AppPermission = action == .deleteRecord || action == .deletePoint
            ? .deleteOperationalRecords
            : .manageOilControlPoints
        masterAuth.request(permission: permission, permissions: permissions) {
            handleAuthorizedMasterAction()
        }
    }

    private func handleAuthorizedMasterAction() {
        switch pendingMasterAction {
        case .addPoint, .editPoint:
            vm.showPointEditor = true
        case .deletePoint:
            guard let point = vm.selectedPoint else { return }
            do {
                try vm.service.deletePoint(point, records: scopedRecords, modelContext: modelContext)
                vm.selectedPoint = nil
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        case .deleteRecord:
            guard let record = recordPendingDeletion else { return }
            do {
                try vm.service.deleteRecord(record, alerts: scopedAlerts, modelContext: modelContext)
            } catch {
                vm.errorMessage = error.localizedDescription
            }
            recordPendingDeletion = nil
        case nil:
            break
        }
        pendingMasterAction = nil
    }

    private func savePoint() {
        guard let rid = appState.activeRestaurantId, let user = currentUser else { return }
        guard permissions.canPerform(vm.pointToEdit == nil ? .manageOilControlPoints : .manageOilControlPoints) else {
            vm.errorMessage = "Serve l'autorizzazione MASTER."
            return
        }
        do {
            if let point = vm.pointToEdit {
                try vm.service.updatePoint(
                    point,
                    name: vm.newPointName,
                    existingPoints: points,
                    modelContext: modelContext
                )
            } else {
                try vm.service.addPoint(
                    name: vm.newPointName,
                    restaurantId: rid,
                    user: user,
                    existingPoints: points,
                    modelContext: modelContext
                )
            }
            vm.showPointEditor = false
            vm.newPointName = ""
            vm.pointToEdit = nil
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}
