import SwiftUI
import SwiftData

struct ProductionSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var categories: [ProductionCategory]
    @Query private var productions: [Production]
    @StateObject private var vm = ProductionSelectionViewModel()
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
                .sorted { $0.name < $1.name }
        }
        return scopedProductions.sorted { $0.name < $1.name }
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
                    .tint(.white)
                    Button("Modifica") { vm.isEditMode.toggle() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Spacer()
                    Button("Annullare", action: onCancel)
                        .buttonStyle(.bordered)
                        .tint(.white)
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
            .background(Color(hex: "#0A0A0A").ignoresSafeArea())
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
                addSheet
            }
        }
    }

    @ViewBuilder
    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("Nuova produzione") {
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
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullare") { vm.showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { addProduction() }
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

    private func addProduction() {
        guard
            let rid = appState.activeRestaurantId,
            let categoryId = vm.newProductionCategoryId,
            let category = scopedCategories.first(where: { $0.id == categoryId })
        else { return }

        let name = vm.newProductionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        modelContext.insert(
            Production(
                restaurantId: rid,
                name: name,
                categoryId: category.id,
                categoryNameSnapshot: category.name,
                isCustom: true
            )
        )
        try? modelContext.save()
        vm.newProductionName = ""
        vm.showAddSheet = false
    }

    private func deleteProduction(_ production: Production) {
        modelContext.delete(production)
        try? modelContext.save()
        vm.selectedProductionIds.remove(production.id)
    }
}
