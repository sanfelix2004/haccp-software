import Foundation
import SwiftData

/// Template prodotti HACCP per la ricezione merci (non sono ricezioni reali).
/// Inseriti per ristorante, senza duplicare per nome.
enum ProductTemplateSeeder {
    private struct Seed {
        let name: String
        let category: GoodsCategory
        let defaultMinTemp: Double?
        let defaultMaxTemp: Double?
        let requiresTemperature: Bool
        let requiresLot: Bool
        let requiresExpiry: Bool
        let requiresPackagingCheck: Bool
        let requiresAppearanceCheck: Bool
        let requiresThawingCheck: Bool
        let requiresMoldCheck: Bool
        let requiresFreshnessCheck: Bool

        init(
            name: String,
            category: GoodsCategory,
            defaultMinTemp: Double? = nil,
            defaultMaxTemp: Double? = nil,
            requiresTemperature: Bool = false,
            requiresLot: Bool = false,
            requiresExpiry: Bool = false,
            requiresPackagingCheck: Bool = true,
            requiresAppearanceCheck: Bool = false,
            requiresThawingCheck: Bool = false,
            requiresMoldCheck: Bool = false,
            requiresFreshnessCheck: Bool = false
        ) {
            self.name = name
            self.category = category
            self.defaultMinTemp = defaultMinTemp
            self.defaultMaxTemp = defaultMaxTemp
            self.requiresTemperature = requiresTemperature
            self.requiresLot = requiresLot
            self.requiresExpiry = requiresExpiry
            self.requiresPackagingCheck = requiresPackagingCheck
            self.requiresAppearanceCheck = requiresAppearanceCheck
            self.requiresThawingCheck = requiresThawingCheck
            self.requiresMoldCheck = requiresMoldCheck
            self.requiresFreshnessCheck = requiresFreshnessCheck
        }
    }

    /// Catalogo base: almeno un esempio per ogni tab categoria (escluso "Tutti").
    private static let seeds: [Seed] = [
        Seed(name: "Carni fresche", category: .freshMeat, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
        Seed(name: "Pesce fresco", category: .freshFish, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
        Seed(name: "Uova", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 10, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Latticini freschi", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Verdura e frutta", category: .produce, requiresAppearanceCheck: true, requiresMoldCheck: true, requiresFreshnessCheck: true),
        Seed(name: "Prodotti secchi", category: .dryProducts, requiresExpiry: true),
        Seed(name: "Prodotti surgelati", category: .frozenProducts, defaultMaxTemp: -18, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresThawingCheck: true),
        Seed(name: "Alimenti misti pronti", category: .combined, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Prodotti confezionati", category: .packaged, requiresLot: true, requiresExpiry: true),
        Seed(name: "Scatolame e lunga conservazione", category: .longShelfLife, requiresLot: true, requiresExpiry: true),
        Seed(name: "Alimenti congelati", category: .frozen, defaultMaxTemp: -18, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Deperibili (generico)", category: .perishable, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true)
    ]

    /// Inserisce i template mancanti per il ristorante (idempotente per nome).
    static func ensureTemplates(restaurantId: UUID, modelContext: ModelContext) {
        let rid = restaurantId
        let descriptor = FetchDescriptor<ProductTemplate>(
            predicate: #Predicate<ProductTemplate> { $0.restaurantId == rid }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map(\.name))
        var didInsert = false
        for seed in seeds where existingNames.contains(seed.name) == false {
            let template = ProductTemplate(
                restaurantId: restaurantId,
                name: seed.name,
                category: seed.category,
                defaultMinTemp: seed.defaultMinTemp,
                defaultMaxTemp: seed.defaultMaxTemp,
                requiresTemperature: seed.requiresTemperature,
                requiresLot: seed.requiresLot,
                requiresExpiry: seed.requiresExpiry,
                requiresPackagingCheck: seed.requiresPackagingCheck,
                requiresAppearanceCheck: seed.requiresAppearanceCheck,
                requiresThawingCheck: seed.requiresThawingCheck,
                requiresMoldCheck: seed.requiresMoldCheck,
                requiresFreshnessCheck: seed.requiresFreshnessCheck
            )
            modelContext.insert(template)
            didInsert = true
        }
        if didInsert {
            try? modelContext.save()
        }
    }
}
