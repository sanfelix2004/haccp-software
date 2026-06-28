import Foundation

/// Ingredienti previsti per ricetta (batch produzione / OCR fallback).
enum ProductionRecipeCatalog {
    private static let recipes: [String: [String]] = [
        "crema pasticcera": ["Uova", "Latte", "Panna", "Zucchero", "Amido di mais"],
        "panna cotta": ["Panna", "Latte", "Zucchero", "Gelatina"],
        "tiramisù": ["Mascarpone", "Uova", "Caffè", "Savoiardi", "Zucchero"],
        "tiramisu": ["Mascarpone", "Uova", "Caffè", "Savoiardi", "Zucchero"],
        "mousse al cioccolato": ["Cioccolato", "Panna", "Uova", "Zucchero"],
        "cheesecake": ["Formaggio spalmabile", "Uova", "Biscotti", "Burro", "Zucchero"],
        "ragù polpo": ["Polpo", "Pomodoro", "Cipolla", "Vino bianco", "Olio"],
        "fonduta pecorino": ["Pecorino", "Latte", "Amido di mais", "Burro"],
        "mayo scapece": ["Uova", "Olio", "Aceto", "Aglio"],
        "salsa basilico": ["Basilico", "Olio", "Parmigiano", "Pinoli", "Aglio"],
        "pane": ["Farina", "Lievito", "Acqua", "Sale"],
        "gelato": ["Latte", "Panna", "Zucchero", "Uova"],
        "tartare": ["Pesce crudo", "Olio", "Limone", "Sale"],
    ]

    static func ingredients(forProductionNamed productionName: String) -> [String] {
        let normalized = productionName
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "it_IT"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let exact = recipes[normalized] { return exact }

        for (key, values) in recipes where normalized.contains(key) {
            return values
        }
        return []
    }

    /// Ingredienti ricetta non ancora associati a una foto nel batch.
    static func pendingIngredients(
        recipe: [String],
        tracked: [IngredienteTracciato]
    ) -> [String] {
        guard !recipe.isEmpty else { return [] }
        let assigned = Set(
            tracked
                .compactMap(\.ingredientNameAssigned)
                .map { normalizeIngredientName($0) }
        )
        return recipe.filter { !assigned.contains(normalizeIngredientName($0)) }
    }

    static func normalizeIngredientName(_ name: String) -> String {
        name
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "it_IT"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Durata suggerita (giorni) dal catalogo statico di fallback.
    static func suggestedDurationDays(forProductionNamed productionName: String) -> Int? {
        let ingredients = ingredients(forProductionNamed: productionName)
        guard !ingredients.isEmpty else { return nil }
        return 3
    }
}
