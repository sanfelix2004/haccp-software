import SwiftUI
import SwiftData

struct BlastChillingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var records: [BlastChillingRecord]
    @Query private var categories: [ProductionCategory]
    @Query private var productions: [Production]
    @StateObject private var vm = BlastChillingViewModel()
    @State private var showMasterEditAuth = false
    @State private var showMasterDeleteAuth = false
    @State private var productionPendingDeletion: Production?
    @State private var recordToComplete: BlastChillingRecord?

    private var scopedRecords: [BlastChillingRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    private var scopedCategories: [ProductionCategory] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return categories.filter { $0.restaurantId == rid }.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var scopedProductions: [Production] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return productions.filter { $0.restaurantId == rid }
    }

    private var filteredProductions: [Production] {
        if let selectedCategoryId = vm.selectedCategoryId {
            return scopedProductions
                .filter { $0.categoryId == selectedCategoryId }
                .sorted(by: productionNameSort)
        }
        return scopedProductions.sorted(by: productionCategorySort)
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var isMaster: Bool {
        currentUser?.role == .master
    }

    private var categoryOrderById: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: scopedCategories.map { ($0.id, $0.orderIndex) })
    }

    private var filteredHistory: [BlastChillingRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: vm.historyStartDate)
        let endStart = calendar.startOfDay(for: vm.historyEndDate)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? vm.historyEndDate
        return scopedRecords.filter { record in
            let categoryOk: Bool = {
                guard let selected = vm.selectedHistoryCategoryId else { return true }
                return record.productionCategorySnapshot == scopedCategories.first(where: { $0.id == selected })?.name
            }()
            let statusOk = vm.selectedHistoryStatus == nil || record.status == vm.selectedHistoryStatus
            let operatorOk = vm.selectedHistoryOperator == "Tutti" || record.createdByNameSnapshot == vm.selectedHistoryOperator
            let periodOk = record.startedAt >= start && record.startedAt <= end
            return categoryOk && statusOk && operatorOk && periodOk
        }
    }

    private var operators: [String] {
        ["Tutti"] + Array(Set(scopedRecords.map(\.createdByNameSnapshot))).sorted()
    }

    private var inProgressRecords: [BlastChillingRecord] {
        scopedRecords
            .filter { $0.status == .inCorso }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var selectedInProgressRecord: BlastChillingRecord? {
        guard let production = vm.selectedProduction else { return nil }
        return inProgressRecords.first { $0.productionId == production.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DashboardCardView(title: "Abbattimento in negativo") {
                    VStack(spacing: 14) {
                        categoryTabs
                        if filteredProductions.isEmpty {
                            DashboardEmptyStateView(state: .init(
                                title: "Nessuna produzione disponibile",
                                message: "Aggiungi una produzione nella categoria selezionata.",
                                actionTitle: nil
                            ))
                        } else {
                            BlastChillingProductionGridView(
                                productions: filteredProductions,
                                selectedProductionId: vm.selectedProduction?.id,
                                onSelect: { vm.selectedProduction = $0 }
                            )
                        }
                        actionBar
                    }
                }

                inProgressCard
                filtersCard
                BlastChillingHistoryView(records: filteredHistory)
            }
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Abbattimento in negativo")
        .onAppear {
            ensureProductions()
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            ensureProductions()
        }
        .sheet(isPresented: $vm.showRecordSheet) {
            if let user = currentUser,
               let rid = appState.activeRestaurantId,
               let production = recordToComplete.flatMap(productionForRecord) ?? vm.selectedProduction {
                BlastChillingRecordSheet(
                    production: production,
                    existingRecord: recordToComplete,
                    operatorName: user.name,
                    validationService: BlastChillingValidationService(),
                    onCancel: {
                        vm.showRecordSheet = false
                        recordToComplete = nil
                    },
                    onStart: { startedAt, initial, target in
                        startRecord(
                            restaurantId: rid,
                            production: production,
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
        .sheet(isPresented: $vm.showAddProductionSheet) {
            productionEditor(title: "Nuova produzione", production: nil)
        }
        .sheet(isPresented: $vm.showEditProductionSheet) {
            if let production = vm.productionToEdit {
                productionEditor(title: "Modifica produzione", production: production)
            }
        }
        .fullScreenCover(isPresented: $showMasterEditAuth) {
            masterOverlay {
                showMasterEditAuth = false
                if let selected = vm.selectedProduction {
                    vm.productionToEdit = selected
                    vm.newProductionName = selected.name
                    vm.newProductionCategoryId = selected.categoryId
                    vm.showEditProductionSheet = true
                }
            } onCancel: {
                showMasterEditAuth = false
            }
        }
        .fullScreenCover(isPresented: $showMasterDeleteAuth) {
            masterOverlay {
                showMasterDeleteAuth = false
                if let production = productionPendingDeletion {
                    deleteProduction(production)
                }
                productionPendingDeletion = nil
            } onCancel: {
                showMasterDeleteAuth = false
                productionPendingDeletion = nil
            }
        }
        .alert("Abbattimento", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryButton(nil, title: "Tutti")
                ForEach(scopedCategories) { category in
                    categoryButton(category.id, title: category.name)
                }
            }
        }
    }

    private func categoryButton(_ id: UUID?, title: String) -> some View {
        Button {
            vm.selectedCategoryId = id
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(vm.selectedCategoryId == id ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(vm.selectedCategoryId == id ? Color.red.opacity(0.65) : Color.white.opacity(0.08))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func productionNameSort(_ lhs: Production, _ rhs: Production) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func productionCategorySort(_ lhs: Production, _ rhs: Production) -> Bool {
        let lhsOrder = categoryOrderById[lhs.categoryId] ?? Int.max
        let rhsOrder = categoryOrderById[rhs.categoryId] ?? Int.max
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }
        return productionNameSort(lhs, rhs)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Aggiungere") {
                vm.newProductionName = ""
                vm.newProductionCategoryId = vm.selectedCategoryId ?? scopedCategories.first?.id
                vm.showAddProductionSheet = true
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button("Modifica") {
                guard vm.selectedProduction != nil else { return }
                showMasterEditAuth = true
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .disabled(vm.selectedProduction == nil)

            Button("Elimina", role: .destructive) {
                guard let selected = vm.selectedProduction else { return }
                productionPendingDeletion = selected
                showMasterDeleteAuth = true
            }
            .buttonStyle(.bordered)
            .disabled(vm.selectedProduction == nil)

            Spacer()

            Button("Annullare") {
                vm.selectedProduction = nil
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button(selectedInProgressRecord == nil ? "Inizia abbattimento" : "Termina abbattimento") {
                if let inProgress = selectedInProgressRecord {
                    recordToComplete = inProgress
                } else {
                    recordToComplete = nil
                }
                vm.showRecordSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.selectedProduction == nil ? .gray : (selectedInProgressRecord == nil ? .green : .orange))
            .disabled(vm.selectedProduction == nil)
        }
    }

    private var inProgressCard: some View {
        DashboardCardView(title: "Abbattimenti in corso") {
            if inProgressRecords.isEmpty {
                DashboardEmptyStateView(state: .init(
                    title: "Nessun abbattimento in corso",
                    message: "Seleziona una produzione e premi Inizia abbattimento.",
                    actionTitle: nil
                ))
            } else {
                VStack(spacing: 10) {
                    ForEach(inProgressRecords) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.productionNameSnapshot)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(record.productionCategorySnapshot) · Inizio \(record.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(record.initialTemperature, specifier: "%.1f") °C")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button("Termina") {
                                recordToComplete = record
                                vm.selectedProduction = productionForRecord(record)
                                vm.showRecordSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    private var filtersCard: some View {
        DashboardCardView(title: "Filtri storico abbattimenti") {
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
            .foregroundColor(.white)
        }
    }

    private func productionEditor(title: String, production: Production?) -> some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("Nome produzione", text: $vm.newProductionName)
                    Picker("Categoria", selection: Binding(
                        get: { vm.newProductionCategoryId ?? scopedCategories.first?.id ?? UUID() },
                        set: { vm.newProductionCategoryId = $0 }
                    )) {
                        ForEach(scopedCategories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                }
                if production != nil {
                    Section {
                        Text("Per eliminare usa il pulsante Elimina nella schermata principale. Anche l'eliminazione richiede autorizzazione MASTER.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullare") {
                        vm.showAddProductionSheet = false
                        vm.showEditProductionSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveProduction(production)
                    }
                    .disabled(vm.newProductionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func masterOverlay(onAuthorized: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .privilegedAction,
                onAuthorized: onAuthorized,
                onCancel: onCancel
            ) { EmptyView() }
        }
    }

    private func ensureProductions() {
        guard let rid = appState.activeRestaurantId else { return }
        vm.productionService.ensureDefaults(
            restaurantId: rid,
            categories: categories,
            productions: productions,
            modelContext: modelContext
        )
    }

    private func productionForRecord(_ record: BlastChillingRecord) -> Production? {
        scopedProductions.first { $0.id == record.productionId }
    }

    private func startRecord(
        restaurantId: UUID,
        production: Production,
        user: LocalUser,
        startedAt: Date,
        initial: Double,
        target: Double
    ) {
        do {
            _ = try vm.service.startRecord(
                restaurantId: restaurantId,
                production: production,
                startedAt: startedAt,
                initialTemperature: initial,
                targetTemperature: target,
                user: user,
                modelContext: modelContext
            )
            vm.showRecordSheet = false
            vm.selectedProduction = nil
            vm.historyEndDate = Date()
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
            vm.selectedProduction = nil
            recordToComplete = nil
            vm.historyEndDate = Date()
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    private func saveProduction(_ production: Production?) {
        guard let rid = appState.activeRestaurantId,
              let categoryId = vm.newProductionCategoryId,
              let category = scopedCategories.first(where: { $0.id == categoryId }) else { return }
        do {
            if let production {
                guard isMaster else { return }
                try vm.service.updateProduction(
                    production,
                    name: vm.newProductionName,
                    category: category,
                    existingProductions: scopedProductions,
                    modelContext: modelContext
                )
                vm.selectedProduction = production
            } else {
                try vm.service.addProduction(
                    name: vm.newProductionName,
                    category: category,
                    restaurantId: rid,
                    existingProductions: scopedProductions,
                    modelContext: modelContext
                )
            }
            vm.showAddProductionSheet = false
            vm.showEditProductionSheet = false
            vm.newProductionName = ""
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    private func deleteProduction(_ production: Production) {
        do {
            try vm.service.deleteProductionIfUnused(
                production,
                records: scopedRecords,
                modelContext: modelContext
            )
            vm.selectedProduction = nil
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}
