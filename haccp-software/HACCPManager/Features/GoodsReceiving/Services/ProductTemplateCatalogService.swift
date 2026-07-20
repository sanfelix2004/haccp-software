import Foundation
import SwiftData

struct ProductTemplateCatalogService {

    /// Assicura le categorie HACCP di default + eventuali categoryRaw già usati nei template.
    @discardableResult
    func ensureCategories(restaurantId: UUID, modelContext: ModelContext) -> Bool {
        let rid = restaurantId
        var descriptor = FetchDescriptor<IncomingFoodCategory>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\IncomingFoodCategory.orderIndex)]
        )
        descriptor.fetchLimit = 200
        var existing = (try? modelContext.fetch(descriptor)) ?? []
        var didMutate = false

        for (index, category) in GoodsCategory.allCases.enumerated() where category != .all {
            if existing.contains(where: { normalized($0.name) == normalized(category.rawValue) }) == false {
                let row = IncomingFoodCategory(
                    restaurantId: restaurantId,
                    name: category.rawValue,
                    orderIndex: index
                )
                modelContext.insert(row)
                existing.append(row)
                didMutate = true
            }
        }

        // Recupera categorie custom già usate nei template ma non ancora in elenco
        var templateDescriptor = FetchDescriptor<ProductTemplate>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        templateDescriptor.fetchLimit = 500
        let templates = (try? modelContext.fetch(templateDescriptor)) ?? []
        var nextIndex = (existing.map(\.orderIndex).max() ?? 0) + 1
        for template in templates {
            let name = template.categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, normalized(name) != "tutti" else { continue }
            if existing.contains(where: { normalized($0.name) == normalized(name) }) == false {
                let row = IncomingFoodCategory(
                    restaurantId: restaurantId,
                    name: name,
                    orderIndex: nextIndex
                )
                modelContext.insert(row)
                existing.append(row)
                nextIndex += 1
                didMutate = true
            }
        }

        if didMutate {
            try? modelContext.save()
        }
        return didMutate
    }

    @discardableResult
    func addCategory(
        name: String,
        restaurantId: UUID,
        existingCategories: [IncomingFoodCategory],
        modelContext: ModelContext
    ) throws -> IncomingFoodCategory {
        ensureCategories(restaurantId: restaurantId, modelContext: modelContext)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw catalogError("Inserisci un nome categoria.")
        }
        guard normalized(trimmed) != "tutti" else {
            throw catalogError("«Tutti» è riservato.")
        }
        if existingCategories.contains(where: { normalized($0.name) == normalized(trimmed) }) {
            throw catalogError("Categoria già presente.")
        }
        let nextIndex = (existingCategories.map(\.orderIndex).max() ?? 0) + 1
        let category = IncomingFoodCategory(
            restaurantId: restaurantId,
            name: trimmed,
            orderIndex: nextIndex
        )
        modelContext.insert(category)
        try modelContext.save()
        return category
    }

    func addTemplate(
        name: String,
        category: GoodsCategory,
        restaurantId: UUID,
        existing: [ProductTemplate],
        modelContext: ModelContext,
        shelfLifeDays: Int? = nil
    ) throws {
        try addTemplate(
            name: name,
            categoryName: category.rawValue,
            restaurantId: restaurantId,
            existing: existing,
            modelContext: modelContext,
            shelfLifeDays: shelfLifeDays
        )
    }

    func addTemplate(
        name: String,
        categoryName: String,
        restaurantId: UUID,
        existing: [ProductTemplate],
        modelContext: ModelContext,
        shelfLifeDays: Int? = nil
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryTrimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !categoryTrimmed.isEmpty, normalized(categoryTrimmed) != "tutti" else {
            throw catalogError("Seleziona una categoria valida.")
        }
        let exists = existing.contains {
            $0.restaurantId == restaurantId &&
            normalized($0.name) == normalized(trimmed)
        }
        guard !exists else {
            throw catalogError("Esiste già un alimento con questo nome.")
        }
        ensureCategories(restaurantId: restaurantId, modelContext: modelContext)
        // Se la categoria non esiste ancora, creala
        let rid = restaurantId
        var catDescriptor = FetchDescriptor<IncomingFoodCategory>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        catDescriptor.fetchLimit = 200
        let cats = (try? modelContext.fetch(catDescriptor)) ?? []
        if cats.contains(where: { normalized($0.name) == normalized(categoryTrimmed) }) == false {
            _ = try addCategory(
                name: categoryTrimmed,
                restaurantId: restaurantId,
                existingCategories: cats,
                modelContext: modelContext
            )
        }
        modelContext.insert(
            ProductTemplate(
                restaurantId: restaurantId,
                name: trimmed,
                categoryName: categoryTrimmed,
                shelfLifeDays: shelfLifeDays
            )
        )
        try modelContext.save()
    }

    func updateTemplate(
        _ template: ProductTemplate,
        name: String,
        category: GoodsCategory,
        existing: [ProductTemplate],
        modelContext: ModelContext,
        shelfLifeDays: Int? = nil
    ) throws {
        try updateTemplate(
            template,
            name: name,
            categoryName: category.rawValue,
            existing: existing,
            modelContext: modelContext,
            shelfLifeDays: shelfLifeDays
        )
    }

    func updateTemplate(
        _ template: ProductTemplate,
        name: String,
        categoryName: String,
        existing: [ProductTemplate],
        modelContext: ModelContext,
        shelfLifeDays: Int? = nil
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryTrimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !categoryTrimmed.isEmpty, normalized(categoryTrimmed) != "tutti" else {
            throw catalogError("Seleziona una categoria valida.")
        }
        let exists = existing.contains {
            $0.id != template.id &&
            $0.restaurantId == template.restaurantId &&
            normalized($0.name) == normalized(trimmed)
        }
        guard !exists else {
            throw catalogError("Esiste già un alimento con questo nome.")
        }
        template.name = trimmed
        template.categoryRaw = categoryTrimmed
        template.shelfLifeDays = shelfLifeDays
        try modelContext.save()
    }

    func deleteTemplateIfUnused(
        _ template: ProductTemplate,
        modelContext: ModelContext
    ) throws {
        let templateId = template.id
        let restaurantId = template.restaurantId

        var receiptDescriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate {
                $0.restaurantId == restaurantId && $0.productTemplateId == templateId
            }
        )
        receiptDescriptor.fetchLimit = 1
        let usedInReceipts = ((try? modelContext.fetch(receiptDescriptor)) ?? []).isEmpty == false

        var defrostDescriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate {
                $0.restaurantId == restaurantId && $0.productTemplateId == templateId
            }
        )
        defrostDescriptor.fetchLimit = 1
        let usedInDefrost = ((try? modelContext.fetch(defrostDescriptor)) ?? []).isEmpty == false

        guard !usedInReceipts, !usedInDefrost else {
            throw catalogError("Alimento già usato in ricezioni o decongelamenti: non può essere eliminato.")
        }
        modelContext.delete(template)
        try modelContext.save()
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func catalogError(_ message: String) -> NSError {
        NSError(domain: "ProductTemplateCatalogService", code: 4200, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
