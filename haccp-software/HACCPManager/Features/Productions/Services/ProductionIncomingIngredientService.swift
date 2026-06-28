import Foundation
import SwiftData

struct ProductionIncomingIngredientService {
    func ingredients(
        productionId: UUID,
        modelContext: ModelContext
    ) -> [ProductionIncomingIngredient] {
        let descriptor = FetchDescriptor<ProductionIncomingIngredient>(
            sortBy: [
                SortDescriptor(\ProductionIncomingIngredient.sortOrder),
                SortDescriptor(\ProductionIncomingIngredient.productNameSnapshot)
            ]
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.productionId == productionId }
    }

    func ingredientNames(
        productionId: UUID,
        modelContext: ModelContext
    ) -> [String] {
        ingredients(productionId: productionId, modelContext: modelContext)
            .map(\.productNameSnapshot)
    }

    func resolvedIngredientNames(
        productionId: UUID,
        productionName: String,
        modelContext: ModelContext
    ) -> [String] {
        let configured = ingredientNames(productionId: productionId, modelContext: modelContext)
        if !configured.isEmpty { return configured }
        return ProductionRecipeCatalog.ingredients(forProductionNamed: productionName)
    }

    func suggestedInternalExpiry(
        productionId: UUID,
        productionName: String,
        modelContext: ModelContext,
        from referenceDate: Date = Date()
    ) -> Date? {
        ScadenzaCalculator.suggestedProductionExpiryDate(
            productionId: productionId,
            productionName: productionName,
            modelContext: modelContext,
            from: referenceDate
        )
    }

    @discardableResult
    func addIngredient(
        production: Production,
        template: ProductTemplate,
        durationDays: Int? = nil,
        modelContext: ModelContext
    ) throws -> ProductionIncomingIngredient {
        let existing = ingredients(productionId: production.id, modelContext: modelContext)
        if existing.contains(where: { $0.productTemplateId == template.id }) {
            throw NSError(
                domain: "ProductionIncomingIngredientService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(template.name) è già nella ricetta."]
            )
        }

        let link = ProductionIncomingIngredient(
            restaurantId: production.restaurantId,
            productionId: production.id,
            productTemplateId: template.id,
            productNameSnapshot: template.name,
            durationDays: 1,
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1
        )
        modelContext.insert(link)
        try modelContext.save()
        return link
    }

    func updateDuration(
        _ link: ProductionIncomingIngredient,
        durationDays: Int,
        modelContext: ModelContext
    ) throws {
        link.durationDays = max(1, durationDays)
        link.updatedAt = Date()
        try modelContext.save()
    }

    func updateTemplate(
        _ link: ProductionIncomingIngredient,
        template: ProductTemplate,
        modelContext: ModelContext
    ) throws {
        let siblings = ingredients(productionId: link.productionId, modelContext: modelContext)
            .filter { $0.id != link.id }
        if siblings.contains(where: { $0.productTemplateId == template.id }) {
            throw NSError(
                domain: "ProductionIncomingIngredientService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "\(template.name) è già nella ricetta."]
            )
        }
        link.productTemplateId = template.id
        link.productNameSnapshot = template.name
        link.updatedAt = Date()
        try modelContext.save()
    }

    func remove(_ link: ProductionIncomingIngredient, modelContext: ModelContext) throws {
        modelContext.delete(link)
        try modelContext.save()
    }

    func isAssigned(
        _ link: ProductionIncomingIngredient,
        in tracked: [IngredienteTracciato]
    ) -> Bool {
        tracked.contains { item in
            if let templateId = item.productTemplateId {
                return templateId == link.productTemplateId
            }
            guard let assigned = item.ingredientNameAssigned?.nilIfEmpty else { return false }
            return ProductionRecipeCatalog.normalizeIngredientName(assigned)
                == ProductionRecipeCatalog.normalizeIngredientName(link.productNameSnapshot)
        }
    }

    func pendingRecipeLinks(
        productionId: UUID,
        tracked: [IngredienteTracciato],
        modelContext: ModelContext
    ) -> [ProductionIncomingIngredient] {
        ingredients(productionId: productionId, modelContext: modelContext)
            .filter { !isAssigned($0, in: tracked) }
    }

    func templateId(
        forIngredientName name: String,
        productionId: UUID,
        modelContext: ModelContext
    ) -> UUID? {
        let normalized = ProductionRecipeCatalog.normalizeIngredientName(name)
        return ingredients(productionId: productionId, modelContext: modelContext)
            .first {
                ProductionRecipeCatalog.normalizeIngredientName($0.productNameSnapshot) == normalized
            }?
            .productTemplateId
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

