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
    @State private var category: GoodsCategory

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
        _category = State(initialValue: .refrigerated)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nuovo alimento in ingresso") {
                    TextField("Nome", text: $name)
                    Picker("Categoria", selection: $category) {
                        ForEach(GoodsCategory.allCases.filter { $0 != .all }) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
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
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            try catalogService.addTemplate(
                name: name,
                category: category,
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
        _shelfLifeDays = State(
            initialValue: ProductionShelfLifeDefaults.days(
                forName: suggestedName,
                categoryName: catName
            )
        )
    }

    private var selectedCategory: ProductionCategory? {
        categories.first { $0.id == categoryId }
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
                Section("Nuovo piatto di produzione") {
                    TextField("Nome piatto", text: $name)
                    Picker("Categoria", selection: $categoryId) {
                        ForEach(categories.filter { $0.name != "Tutti" }) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .onChange(of: categoryId) { _, _ in
                        shelfLifeDays = suggestedDays
                    }
                    .onChange(of: name) { _, _ in
                        shelfLifeDays = suggestedDays
                    }
                }

                Section("Durata conservazione piatto finito") {
                    HStack {
                        Text("Suggerita")
                        Spacer()
                        Text("\(suggestedDays) giorni")
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    ShelfLifeDaysNumberField(days: $shelfLifeDays, label: "Durata")
                }
            }
            .navigationTitle("Aggiungi piatto")
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
