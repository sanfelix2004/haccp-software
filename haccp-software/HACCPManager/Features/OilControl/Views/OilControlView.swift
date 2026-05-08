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
    @State private var showMasterAuth = false
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

    private var isMaster: Bool {
        currentUser?.role == .master
    }

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
                DashboardCardView(title: "Controllo olio") {
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
                OilHistoryView(records: filteredHistory, canDelete: isMaster) { record in
                    recordPendingDeletion = record
                    pendingMasterAction = .deleteRecord
                    showMasterAuth = true
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
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
        .fullScreenCover(isPresented: $showMasterAuth) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .privilegedAction,
                    onAuthorized: handleAuthorizedMasterAction,
                    onCancel: {
                        showMasterAuth = false
                        pendingMasterAction = nil
                        recordPendingDeletion = nil
                    }
                ) { EmptyView() }
            }
        }
        .alert("Controllo olio", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var headerMetrics: some View {
        HStack(spacing: 10) {
            metric(title: "Punti olio", value: "\(scopedPoints.count)")
            metric(title: "Controlli", value: "\(scopedRecords.count)")
            metric(title: "Alert attivi", value: "\(scopedAlerts.filter { $0.isActive }.count)")
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Aggiungere") {
                vm.pointToEdit = nil
                vm.newPointName = ""
                pendingMasterAction = .addPoint
                showMasterAuth = true
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button("Modifica") {
                guard let selected = vm.selectedPoint else {
                    vm.errorMessage = "Seleziona un punto olio da modificare."
                    return
                }
                vm.pointToEdit = selected
                vm.newPointName = selected.name
                pendingMasterAction = .editPoint
                showMasterAuth = true
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .disabled(vm.selectedPoint == nil)

            Button("Elimina", role: .destructive) {
                guard vm.selectedPoint != nil else { return }
                pendingMasterAction = .deletePoint
                showMasterAuth = true
            }
            .buttonStyle(.bordered)
            .disabled(vm.selectedPoint == nil)

            Spacer()

            Button("Inserisci controllo") {
                vm.showCheckSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.selectedPoint == nil ? .gray : .green)
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
            .foregroundColor(.white)
        }
    }

    private var pointEditor: some View {
        NavigationStack {
            Form {
                Section(vm.pointToEdit == nil ? "Nuovo punto olio" : "Modifica punto olio") {
                    TextField("Nome punto olio", text: $vm.newPointName)
                }
            }
            .navigationTitle(vm.pointToEdit == nil ? "Aggiungere" : "Modifica")
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

    private func handleAuthorizedMasterAction() {
        showMasterAuth = false
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
