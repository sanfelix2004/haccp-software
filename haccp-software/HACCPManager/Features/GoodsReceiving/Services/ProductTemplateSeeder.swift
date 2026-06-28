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
        Seed(name: "Deperibili (generico)", category: .perishable, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),

        // Ingredienti specifici (durata HACCP realistica)
        Seed(name: "Mozzarella di bufala", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Pomodoro pelato", category: .packaged, requiresLot: true, requiresExpiry: true),
        Seed(name: "Pomodoro fresco", category: .produce, requiresAppearanceCheck: true, requiresMoldCheck: true),
        Seed(name: "Olio extravergine", category: .packaged, requiresLot: true, requiresExpiry: true),
        Seed(name: "Basilico fresco", category: .produce, requiresAppearanceCheck: true, requiresFreshnessCheck: true),
        Seed(name: "Alici fresche", category: .freshFish, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
        Seed(name: "Tonno fresco", category: .freshFish, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
        Seed(name: "Gamberi", category: .freshFish, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
        Seed(name: "Polpo", category: .freshFish, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
        Seed(name: "Latte intero", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Panna fresca", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Parmigiano Reggiano", category: .refrigerated, requiresLot: true, requiresExpiry: true),
        Seed(name: "Pecorino", category: .refrigerated, requiresLot: true, requiresExpiry: true),
        Seed(name: "Mascarpone", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Burro", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
        Seed(name: "Farina tipo 00", category: .dryProducts, requiresLot: true, requiresExpiry: true),
        Seed(name: "Zucchero", category: .dryProducts),
        Seed(name: "Sale fino", category: .dryProducts),
        Seed(name: "Caffè", category: .dryProducts),
        Seed(name: "Cioccolato fondente", category: .dryProducts, requiresLot: true, requiresExpiry: true),
        Seed(name: "Savoiardi", category: .dryProducts, requiresLot: true, requiresExpiry: true),
        Seed(name: "Pinoli", category: .dryProducts, requiresLot: true, requiresExpiry: true),
        Seed(name: "Capperi", category: .packaged, requiresLot: true, requiresExpiry: true),
        Seed(name: "Olive", category: .packaged, requiresLot: true, requiresExpiry: true),
        Seed(name: "Aceto", category: .packaged, requiresLot: true, requiresExpiry: true),
        Seed(name: "Vino bianco", category: .packaged, requiresLot: true, requiresExpiry: true),
        Seed(name: "Riso", category: .dryProducts, requiresLot: true, requiresExpiry: true),
        Seed(name: "Pasta secca", category: .dryProducts, requiresLot: true, requiresExpiry: true)
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
                requiresFreshnessCheck: seed.requiresFreshnessCheck,
                shelfLifeDays: IncomingFoodShelfLifeDefaults.days(forName: seed.name, category: seed.category)
            )
            modelContext.insert(template)
            didInsert = true
        }
        var didBackfill = false
        for template in existing where template.shelfLifeDays == nil {
            template.shelfLifeDays = IncomingFoodShelfLifeDefaults.days(forName: template.name, category: template.category)
            didBackfill = true
        }
        if didInsert || didBackfill {
            try? modelContext.save()
        }
    }
}
