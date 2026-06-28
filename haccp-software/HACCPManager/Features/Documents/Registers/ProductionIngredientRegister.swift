import Foundation

/// Produzioni del catalogo con ingredienti configurati e lotti effettivamente collegati nel periodo.
enum ProductionIngredientRegister {
    struct Row {
        let production: String
        let category: String
        let ingredientsConfigured: String
        let lotsUsedInPeriod: String
        let lastLinkedAt: String
    }

    static func rows(
        in interval: DateInterval,
        productions: [Production],
        incomingIngredients: [ProductionIncomingIngredient],
        links: [TraceabilityLink],
        traceability: [TraceabilityRecord],
        df: DateFormatter
    ) -> [Row] {
        let ingredientsByProduction = Dictionary(grouping: incomingIngredients, by: \.productionId)
        let linksByProduction = Dictionary(grouping: links, by: \.productionId)
        let traceById = Dictionary(uniqueKeysWithValues: traceability.map { ($0.id, $0) })

        let activeProductionIds = Set(
            links
                .filter { interval.contains($0.createdAt) }
                .map(\.productionId)
        )

        return productions
            .filter { activeProductionIds.contains($0.id) || interval.contains($0.createdAt) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { production in
                let configured = (ingredientsByProduction[production.id] ?? [])
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map(\.productNameSnapshot)
                    .joined(separator: ", ")

                let periodLinks = (linksByProduction[production.id] ?? [])
                    .filter { interval.contains($0.createdAt) }
                    .sorted { $0.createdAt > $1.createdAt }

                let lots = periodLinks.compactMap { link -> String? in
                    guard let record = traceById[link.receivedItemId] else { return nil }
                    let lot = record.lotCode.isEmpty ? "—" : record.lotCode
                    return "\(record.productName) (\(lot))"
                }
                .joined(separator: "; ")

                let lastLinked = periodLinks.first.map { df.string(from: $0.createdAt) } ?? "—"

                return Row(
                    production: production.name,
                    category: production.categoryNameSnapshot,
                    ingredientsConfigured: configured.isEmpty ? "—" : configured,
                    lotsUsedInPeriod: lots.isEmpty ? "—" : lots,
                    lastLinkedAt: lastLinked
                )
            }
    }

    static func hasActivity(
        in interval: DateInterval,
        productions: [Production],
        links: [TraceabilityLink],
        traceability: [TraceabilityRecord]
    ) -> Bool {
        if links.contains(where: { interval.contains($0.createdAt) }) { return true }
        let hubRecords = traceability.filter {
            TraceabilityRecordSupport.isHubRecord($0) && interval.contains($0.receivedAt)
        }
        if !hubRecords.isEmpty { return true }
        return productions.contains { interval.contains($0.createdAt) }
    }
}
