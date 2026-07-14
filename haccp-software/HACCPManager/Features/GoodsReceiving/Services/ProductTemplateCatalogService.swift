import Foundation
import SwiftData

struct ProductTemplateCatalogService {

    func addTemplate(
        name: String,
        category: GoodsCategory,
        restaurantId: UUID,
        existing: [ProductTemplate],
        modelContext: ModelContext,
        shelfLifeDays: Int? = nil
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard category != .all else {
            throw catalogError("Seleziona una categoria valida.")
        }
        let exists = existing.contains {
            $0.restaurantId == restaurantId &&
            normalized($0.name) == normalized(trimmed)
        }
        guard !exists else {
            throw catalogError("Esiste già un alimento con questo nome.")
        }
        modelContext.insert(
            ProductTemplate(
                restaurantId: restaurantId,
                name: trimmed,
                category: category,
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard category != .all else {
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
        template.category = category
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
