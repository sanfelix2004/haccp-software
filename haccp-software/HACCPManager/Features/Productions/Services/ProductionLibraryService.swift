import Foundation
import SwiftData

struct ProductionLibraryService {
    func ensureDefaults(
        restaurantId: UUID,
        categories: [ProductionCategory],
        productions: [Production],
        modelContext: ModelContext
    ) {
        let scopedCategories = categories.filter { $0.restaurantId == restaurantId }
        if scopedCategories.isEmpty {
            let names = ["Antipasti", "Contorni", "Crudi", "Dolci", "Entre", "Pane", "Primi", "Salse vegetali", "Secondi"]
            for (index, name) in names.enumerated() {
                modelContext.insert(ProductionCategory(restaurantId: restaurantId, name: name, orderIndex: index))
            }
            try? modelContext.save()
        }

        let refreshedCategories = (try? modelContext.fetch(FetchDescriptor<ProductionCategory>()))?.filter { $0.restaurantId == restaurantId } ?? []
        let scopedProductions = productions.filter { $0.restaurantId == restaurantId }
        if scopedProductions.isEmpty {
            let dictionary: [String: [String]] = [
                "Antipasti": ["Alici", "Astice", "Baccala", "Branzino", "Bufala", "Calamaro", "Cozze pastellate"],
                "Contorni": ["Cipolla caramellata", "Concasse pomodoro", "Indivia", "Melanzane", "Porro", "Zucchine cotte"],
                "Crudi": ["Gambero bianco", "Gambero rosso", "Tonno", "Ostriche", "Pesce spada crudo", "Mazzancolle"],
                "Dolci": ["Brownie", "Crema inglese", "Crema limone", "Mousse ricotta", "Namelaka", "Semifreddi"],
                "Entre": ["Cialdella", "Mousse menta curry", "Salsa apetaizer"],
                "Pane": ["Pane"],
                "Primi": ["Fonduta pecorino", "Peperone giallo", "Pomodorino", "Ragusa polpo"],
                "Salse vegetali": [
                    "Acqua cipolla", "Barbabietola", "Carota", "Gazpacho pomodoro", "Lenticchie",
                    "Peperone rosso", "Peperone verde", "Lattughino liquido", "Mayo scapece",
                    "Salsa basilico", "Salsa cicoria", "Salsa finocchietto", "Salsa pizzaiola",
                    "Salsa taralli", "Salsa zafferano", "Salsa zucca", "Sedano rapa", "Topinambur", "Yogurt"
                ],
                "Secondi": [
                    "Astice", "Calamaro", "Carcifi", "Coppa di suino", "Crema ceci",
                    "Cube roll", "Dentice filetto", "Filetti orata", "Filetto di spigola",
                    "Guancia", "Pagro", "Pescatrice", "Polenta", "Pollo", "Polpo", "Rombo", "Sarago", "Sgombro", "Tonno in nero"
                ]
            ]
            for category in refreshedCategories {
                for productionName in dictionary[category.name] ?? [] {
                    modelContext.insert(
                        Production(
                            restaurantId: restaurantId,
                            name: productionName,
                            categoryId: category.id,
                            categoryNameSnapshot: category.name,
                            isCustom: false
                        )
                    )
                }
            }
            try? modelContext.save()
        }
    }

    func associate(
        record: TraceabilityRecord,
        production: Production,
        quantityUsed: Double?,
        operatorName: String,
        links: [TraceabilityLink],
        modelContext: ModelContext
    ) throws {
        guard record.productStatus != .expired, record.productStatus != .rejected else {
            throw NSError(domain: "ProductionLibraryService", code: 7001, userInfo: [NSLocalizedDescriptionKey: "Prodotto non associabile: scaduto o respinto."])
        }
        if links.contains(where: { $0.receivedItemId == record.id && $0.productionId == production.id }) {
            return
        }
        let link = TraceabilityLink(
            receivedItemId: record.id,
            productionId: production.id,
            quantityUsed: quantityUsed
        )
        modelContext.insert(link)
        let current = record.productionReference?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        if current.contains(production.name) {
            record.productionReference = current.joined(separator: ", ")
        } else {
            record.productionReference = (current + [production.name]).joined(separator: ", ")
        }
        if record.productStatus == .available {
            record.productStatus = .partiallyUsed
        }
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                productionId: production.id,
                actionType: .linkedToProduction,
                operatorName: operatorName
            )
        )
        try modelContext.save()
    }

    func syncAssociations(
        record: TraceabilityRecord,
        selectedProductions: [Production],
        operatorName: String,
        links: [TraceabilityLink],
        modelContext: ModelContext
    ) throws {
        let existing = links.filter { $0.receivedItemId == record.id }
        let existingIds = Set(existing.map(\.productionId))
        let selectedIds = Set(selectedProductions.map(\.id))

        for link in existing where selectedIds.contains(link.productionId) == false {
            modelContext.delete(link)
        }

        for production in selectedProductions where existingIds.contains(production.id) == false {
            try associate(
                record: record,
                production: production,
                quantityUsed: nil,
                operatorName: operatorName,
                links: links,
                modelContext: modelContext
            )
        }

        let names = selectedProductions.map(\.name).sorted()
        record.productionReference = names.isEmpty ? nil : names.joined(separator: ", ")
        if selectedIds.isEmpty && record.productStatus == .partiallyUsed {
            record.productStatus = .available
        }
        try modelContext.save()
    }
}
