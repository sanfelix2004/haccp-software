import Foundation

/// Ricerca archivio tracciabilità: token multi-parola, senza accenti.
enum TraceabilityArchiveSearch {
    static func tokens(from text: String) -> [String] {
        normalize(text)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { $0.count >= 2 || Int($0) != nil }
    }

    static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "it_IT"))
            .lowercased()
    }

    static func matchesAllTokens(_ tokens: [String], in fields: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        let haystacks = fields.map(normalize).filter { !$0.isEmpty }
        guard !haystacks.isEmpty else { return false }
        return tokens.allSatisfy { token in
            haystacks.contains { $0.contains(token) }
        }
    }

    /// Punteggio rilevanza gruppo archivio (piatto > ingrediente).
    static func groupRelevanceScore(
        productionName: String,
        categoryName: String?,
        ingredients: [TraceabilityArchiveIngredientItem],
        tokens: [String]
    ) -> Int {
        guard !tokens.isEmpty else { return 0 }
        var score = 0
        let dish = normalize(productionName)
        let category = categoryName.map(normalize) ?? ""

        for token in tokens {
            if dish.hasPrefix(token) { score += 120 }
            else if dish.contains(token) { score += 80 }
            if category.contains(token) { score += 40 }
            for ingredient in ingredients {
                let name = normalize(ingredient.name)
                let lot = normalize(ingredient.lotCode)
                let supplier = normalize(ingredient.supplier)
                if name.hasPrefix(token) { score += 50 }
                else if name.contains(token) { score += 30 }
                if lot.contains(token) { score += 35 }
                if supplier.contains(token) { score += 20 }
            }
        }
        return score
    }

    static func groupMatchesSearch(
        productionName: String,
        categoryName: String?,
        ingredients: [TraceabilityArchiveIngredientItem],
        tokens: [String],
        batchCode: String? = nil
    ) -> Bool {
        let fields = [productionName, categoryName ?? "", batchCode ?? ""] + ingredients.flatMap {
            [$0.name, $0.lotCode, $0.supplier]
        }
        return matchesAllTokens(tokens, in: fields)
    }
}
