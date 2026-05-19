import SwiftUI
import SwiftData

struct ProductionSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var categories: [ProductionCategory]
    @Query private var productions: [Production]
    @Query private var links: [TraceabilityLink]
    @Query private var blastRecords: [BlastChillingRecord]
    @StateObject private var vm = ProductionSelectionViewModel()
    @State private var showMasterAuthForEdit = false
    @State private var showMasterAuthForDelete = false
    @State private var productionPendingDeletion: Production?
    private let service = ProductionLibraryService()
    let initialSelectedIds: Set<UUID>

    let onCancel: () -> Void
    let onConfirm: ([Production]) -> Void

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

    private var selectedSingleProduction: Production? {
        guard vm.selectedProductionIds.count == 1,
              let id = vm.selectedProductionIds.first else { return nil }
        return scopedProductions.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        categoryButton(nil, title: "Tutti")
                        ForEach(scopedCategories) { category in
                            categoryButton(category.id, title: category.name)
                        }
                    }
                }

                ScrollView {
                    ProductionGrid(
                        productions: filteredProductions,
                        selectedProductionIds: vm.selectedProductionIds,
                        isEditMode: vm.isEditMode,
                        onSelect: { production in
                            if vm.selectedProductionIds.contains(production.id) {
                                vm.selectedProductionIds.remove(production.id)
                            } else {
                                vm.selectedProductionIds.insert(production.id)
                            }
                        },
                        onDelete: deleteProduction
                    )
                    .padding(.bottom, 10)
                }

                HStack(spacing: 10) {
                    Button("+ Aggiungere") {
                        vm.newProductionCategoryId = vm.selectedCategoryId ?? scopedCategories.first?.id
                        vm.showAddSheet = true
                    }
                    .buttonStyle(.bordered)
                    .tint(ThemeManager.shared.colorPrimary)
                    Button("Modifica") {
                        guard let selected = selectedSingleProduction else {
                            vm.errorMessage = "Seleziona una sola produzione da modificare."
                            return
                        }
                        vm.productionToEdit = selected
                        showMasterAuthForEdit = true
                    }
                        .buttonStyle(.bordered)
                        .tint(ThemeManager.shared.colorPrimary)
                        .disabled(selectedSingleProduction == nil)
                    Button("Elimina", role: .destructive) {
                        guard let selected = selectedSingleProduction else {
                            vm.errorMessage = "Seleziona una sola produzione da eliminare."
                            return
                        }
                        productionPendingDeletion = selected
                        showMasterAuthForDelete = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedSingleProduction == nil)
                    Spacer()
                    Button("Annullare", action: onCancel)
                        .buttonStyle(.bordered)
                        .tint(ThemeManager.shared.colorPrimary)
                    Button("Ho finito") {
                        let selected = scopedProductions.filter { vm.selectedProductionIds.contains($0.id) }
                        onConfirm(selected)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.selectedProductionIds.isEmpty ? .gray : .green)
                    .disabled(vm.selectedProductionIds.isEmpty)
                }
            }
            .padding(20)
            .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
            .navigationTitle("Produzioni")
            .onAppear {
                vm.selectedProductionIds = initialSelectedIds
                guard let rid = appState.activeRestaurantId else { return }
                service.ensureDefaults(
                    restaurantId: rid,
                    categories: categories,
                    productions: productions,
                    modelContext: modelContext
                )
            }
            .sheet(isPresented: $vm.showAddSheet) {
                productionEditor(title: "Nuova produzione", production: nil)
            }
            .sheet(isPresented: $vm.showEditSheet) {
                if let production = vm.productionToEdit {
                    productionEditor(title: "Modifica produzione", production: production)
                }
            }
            .fullScreenCover(isPresented: $showMasterAuthForEdit) {
                masterOverlay {
                    showMasterAuthForEdit = false
                    if let production = vm.productionToEdit {
                        vm.newProductionName = production.name
                        vm.newProductionCategoryId = production.categoryId
                        vm.showEditSheet = true
                    }
                } onCancel: {
                    showMasterAuthForEdit = false
                    vm.productionToEdit = nil
                }
            }
            .fullScreenCover(isPresented: $showMasterAuthForDelete) {
                masterOverlay {
                    showMasterAuthForDelete = false
                    if let production = productionPendingDeletion {
                        performDeleteProduction(production)
                    }
                    productionPendingDeletion = nil
                } onCancel: {
                    showMasterAuthForDelete = false
                    productionPendingDeletion = nil
                }
            }
            .alert("Produzioni", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
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
                        Text("La modifica è riservata al MASTER. La produzione resta condivisa tra Abbattimento e Tracciabilità.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullare") {
                        vm.showAddSheet = false
                        vm.showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveProduction(production) }
                        .disabled(vm.newProductionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                .foregroundStyle(vm.selectedCategoryId == id ? ThemeManager.shared.colorTextOnPrimary : ThemeManager.shared.colorTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(vm.selectedCategoryId == id ? ThemeManager.shared.colorPrimary : ThemeManager.shared.colorDivider)
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

    private func saveProduction(_ production: Production?) {
        guard
            let rid = appState.activeRestaurantId,
            let categoryId = vm.newProductionCategoryId,
            let category = scopedCategories.first(where: { $0.id == categoryId })
        else { return }

        do {
            if let production {
                guard isMaster else { return }
                try service.updateProduction(
                    production,
                    name: vm.newProductionName,
                    category: category,
                    existingProductions: scopedProductions,
                    modelContext: modelContext
                )
            } else {
                try service.addProduction(
                    name: vm.newProductionName,
                    category: category,
                    restaurantId: rid,
                    existingProductions: scopedProductions,
                    modelContext: modelContext
                )
            }
            vm.newProductionName = ""
            vm.showAddSheet = false
            vm.showEditSheet = false
        } catch {
            vm.errorMessage = error.localizedDescription
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
            ) {
                EmptyView()
            }
        }
    }

    private func deleteProduction(_ production: Production) {
        guard isMaster else {
            productionPendingDeletion = production
            showMasterAuthForDelete = true
            return
        }
        performDeleteProduction(production)
    }

    private func performDeleteProduction(_ production: Production) {
        do {
            try service.deleteProductionIfUnused(
                production,
                traceabilityLinks: links,
                blastRecords: blastRecords,
                modelContext: modelContext
            )
            vm.selectedProductionIds.remove(production.id)
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}
