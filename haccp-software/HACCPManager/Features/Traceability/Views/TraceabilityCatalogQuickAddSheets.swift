import SwiftUI
import SwiftData

/// Aggiunta rapida alimento in ingresso durante la tracciabilità.
struct TraceabilityQuickAddIncomingFoodSheet: View {
    let restaurantId: UUID
    let existingTemplates: [ProductTemplate]
    var suggestedName: String = ""
    let onSaved: (ProductTemplate) -> Void
    let onCancel: () -> Void
    var onError: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var name: String
    @State private var categoryName: String
    @State private var categories: [IncomingFoodCategory] = []
    @State private var showAddCategory = false

    private let catalogService = ProductTemplateCatalogService()

    init(
        restaurantId: UUID,
        existingTemplates: [ProductTemplate],
        suggestedName: String = "",
        onSaved: @escaping (ProductTemplate) -> Void,
        onCancel: @escaping () -> Void,
        onError: ((String) -> Void)? = nil
    ) {
        self.restaurantId = restaurantId
        self.existingTemplates = existingTemplates
        self.suggestedName = suggestedName
        self.onSaved = onSaved
        self.onCancel = onCancel
        self.onError = onError
        _name = State(initialValue: suggestedName)
        _categoryName = State(initialValue: GoodsCategory.refrigerated.rawValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nuovo alimento in ingresso") {
                    TextField("Nome", text: $name)
                    Picker("Categoria", selection: $categoryName) {
                        ForEach(categories) { cat in
                            Text(cat.name).tag(cat.name)
                        }
                    }
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Aggiungi categoria", systemImage: "folder.badge.plus")
                    }
                }

                Section {
                    Text("La scadenza si imposta in tracciabilità (lettura etichetta o data manuale).")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .navigationTitle("Aggiungi alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") { save() }
                        .disabled(
                            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || categoryName.isEmpty
                        )
                }
            }
            .onAppear(perform: reloadCategories)
            .sheet(isPresented: $showAddCategory) {
                CatalogAddCategorySheet(
                    title: "Categoria alimenti",
                    placeholder: "Es. Latticini…",
                    existingNames: categories.map(\.name),
                    onSave: { newName in
                        do {
                            let created = try catalogService.addCategory(
                                name: newName,
                                restaurantId: restaurantId,
                                existingCategories: categories,
                                modelContext: modelContext
                            )
                            categoryName = created.name
                            showAddCategory = false
                            reloadCategories()
                        } catch {
                            onError?(error.localizedDescription)
                            showAddCategory = false
                        }
                    },
                    onCancel: { showAddCategory = false }
                )
            }
        }
    }

    private func reloadCategories() {
        catalogService.ensureCategories(restaurantId: restaurantId, modelContext: modelContext)
        let rid = restaurantId
        var descriptor = FetchDescriptor<IncomingFoodCategory>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\IncomingFoodCategory.orderIndex)]
        )
        descriptor.fetchLimit = 200
        categories = (try? modelContext.fetch(descriptor)) ?? []
        if categories.contains(where: { $0.name == categoryName }) == false {
            categoryName = categories.first?.name ?? GoodsCategory.refrigerated.rawValue
        }
    }

    private func save() {
        do {
            try catalogService.addTemplate(
                name: name,
                categoryName: categoryName,
                restaurantId: restaurantId,
                existing: existingTemplates,
                modelContext: modelContext,
                shelfLifeDays: nil
            )
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let created = ((try? modelContext.fetch(FetchDescriptor<ProductTemplate>())) ?? [])
                .first(where: { $0.restaurantId == restaurantId && $0.name == trimmed }) {
                onSaved(created)
            } else {
                onCancel()
            }
        } catch {
            onError?((error as NSError).localizedDescription)
        }
    }
}

/// Aggiunta rapida piatto di produzione durante la tracciabilità.
struct TraceabilityQuickAddProductionSheet: View {
    let restaurantId: UUID
    let categories: [ProductionCategory]
    let existingProductions: [Production]
    var suggestedName: String = ""
    let onSaved: (Production) -> Void
    let onCancel: () -> Void
    var onError: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var name: String
    @State private var categoryId: UUID
    @State private var shelfLifeDays: Int
    @State private var localCategories: [ProductionCategory]
    @State private var showAddCategory = false

    private let libraryService = ProductionLibraryService()

    init(
        restaurantId: UUID,
        categories: [ProductionCategory],
        existingProductions: [Production],
        suggestedName: String = "",
        onSaved: @escaping (Production) -> Void,
        onCancel: @escaping () -> Void,
        onError: ((String) -> Void)? = nil
    ) {
        self.restaurantId = restaurantId
        self.categories = categories
        self.existingProductions = existingProductions
        self.suggestedName = suggestedName
        self.onSaved = onSaved
        self.onCancel = onCancel
        self.onError = onError
        let defaultCategory = categories.first(where: { $0.name != "Tutti" }) ?? categories.first
        let catId = defaultCategory?.id ?? UUID()
        let catName = defaultCategory?.name ?? ""
        _name = State(initialValue: suggestedName)
        _categoryId = State(initialValue: catId)
        _localCategories = State(initialValue: categories)
        _shelfLifeDays = State(
            initialValue: ProductionShelfLifeDefaults.days(
                forName: suggestedName,
                categoryName: catName
            )
        )
    }

    private var selectedCategory: ProductionCategory? {
        localCategories.first { $0.id == categoryId }
    }

    private var suggestedDays: Int {
        ProductionShelfLifeDefaults.days(
            forName: name.isEmpty ? " " : name,
            categoryName: selectedCategory?.name ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nuovo alimento produzione") {
                    TextField("Nome alimento", text: $name)
                    Picker("Categoria", selection: $categoryId) {
                        ForEach(localCategories.filter { $0.name != "Tutti" }) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .onChange(of: categoryId) { _, _ in
                        shelfLifeDays = suggestedDays
                    }
                    .onChange(of: name) { _, _ in
                        shelfLifeDays = suggestedDays
                    }
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Aggiungi categoria", systemImage: "folder.badge.plus")
                    }
                }

                Section("Durata conservazione") {
                    HStack {
                        Text("Suggerita")
                        Spacer()
                        Text("\(suggestedDays) giorni")
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    ShelfLifeDaysNumberField(days: $shelfLifeDays, label: "Durata")
                }
            }
            .navigationTitle("Aggiungi alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showAddCategory) {
                CatalogAddCategorySheet(
                    title: "Categoria piatti",
                    placeholder: "Es. Bevande…",
                    existingNames: localCategories.map(\.name),
                    onSave: { newName in
                        do {
                            let created = try libraryService.addCategory(
                                name: newName,
                                restaurantId: restaurantId,
                                existingCategories: localCategories,
                                modelContext: modelContext
                            )
                            localCategories.append(created)
                            categoryId = created.id
                            shelfLifeDays = suggestedDays
                            showAddCategory = false
                        } catch {
                            onError?(error.localizedDescription)
                            showAddCategory = false
                        }
                    },
                    onCancel: { showAddCategory = false }
                )
            }
        }
    }

    private func save() {
        guard let category = selectedCategory else { return }
        do {
            try libraryService.addProduction(
                name: name,
                category: category,
                restaurantId: restaurantId,
                existingProductions: existingProductions,
                modelContext: modelContext,
                shelfLifeDays: shelfLifeDays
            )
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let created = ((try? modelContext.fetch(FetchDescriptor<Production>())) ?? [])
                .first(where: {
                    $0.restaurantId == restaurantId
                        && $0.categoryId == category.id
                        && $0.name == trimmed
                }) {
                onSaved(created)
            } else {
                onCancel()
            }
        } catch {
            onError?((error as NSError).localizedDescription)
        }
    }
}
