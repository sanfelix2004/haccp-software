import Foundation
import SwiftData

struct ProductionLibraryService {
    private static let defaultCategoryNames = [
        "Tutti",
        "Antipasti",
        "Crudi",
        "Dolci",
        "Secondi",
        "Contorni",
        "Entrè",
        "Pane",
        "Primi",
        "Salse vegetali"
    ]

    private static let defaultProductionsByCategory: [String: [String]] = [
        "Antipasti": [
            "Alici", "Baccalà", "Bufala", "Cozze pastellate", "Emulsione cozze",
            "Guancia", "Mozzarella di bufala", "Peperone rosso", "Peperone verde",
            "Polipetti", "Razza", "Triglia"
        ],
        "Crudi": [
            "Astice", "Calamari", "Calamaro", "Gambero bianco", "Gambero rosso di mazzara",
            "Mazzancolle", "Pescatrice", "Pesce spada", "Ricciola", "Tagliatelle",
            "Tartare", "Tonno"
        ],
        "Dolci": [
            "Astice", "Branzino", "Cube roll", "Dentice", "Filetti orata", "Filetto di spigola"
        ],
        "Secondi": [
            "Astice", "Branzino", "Cube roll", "Dentice", "Filetti orata", "Filetto di spigola",
            "Ostriche", "Pagro", "Petto pollo", "Sgombro", "Tonno in nero", "Tonno in panatura nera"
        ],
        "Contorni": ["Cipolla caramellata", "Concasse pomodoro", "Indivia", "Melanzane", "Porro", "Zucchine cotte"],
        "Entrè": ["Cialdella", "Mousse menta curry", "Salsa appetizer"],
        "Pane": ["Pane"],
        "Primi": ["Fonduta pecorino", "Peperone giallo", "Pomodorino", "Ragù polpo"],
        "Salse vegetali": [
            "Acqua cipolla", "Barbabietola", "Carota", "Gazpacho pomodoro", "Lenticchie",
            "Lattughino liquido", "Mayo scapece", "Salsa basilico", "Salsa cicoria",
            "Salsa finocchietto", "Salsa pizzaiola", "Salsa taralli", "Salsa zafferano",
            "Salsa zucca", "Sedano rapa", "Topinambur", "Yogurt"
        ]
    ]

    func ensureDefaults(
        restaurantId: UUID,
        categories: [ProductionCategory],
        productions: [Production],
        modelContext: ModelContext
    ) {
        var scopedCategories = categories.filter { $0.restaurantId == restaurantId }
        if let legacyEntre = scopedCategories.first(where: { normalized($0.name) == "entre" }) {
            legacyEntre.name = "Entrè"
        }
        for (index, name) in Self.defaultCategoryNames.enumerated() {
            guard name != "Tutti" else { continue }
            if scopedCategories.contains(where: { normalized($0.name) == normalized(name) }) == false {
                let category = ProductionCategory(restaurantId: restaurantId, name: name, orderIndex: index)
                modelContext.insert(category)
                scopedCategories.append(category)
            } else if let category = scopedCategories.first(where: { normalized($0.name) == normalized(name) }) {
                category.orderIndex = index
            }
        }
        try? modelContext.save()

        let refreshedCategories = (try? modelContext.fetch(FetchDescriptor<ProductionCategory>()))?.filter { $0.restaurantId == restaurantId } ?? []
        let scopedProductions = productions.filter { $0.restaurantId == restaurantId }
        for category in refreshedCategories {
            let categoryName = category.name == "Entre" ? "Entrè" : category.name
            for productionName in Self.defaultProductionsByCategory[categoryName] ?? [] {
                let alreadyExists = scopedProductions.contains {
                    $0.restaurantId == restaurantId &&
                    $0.categoryId == category.id &&
                    normalized($0.name) == normalized(productionName)
                }
                guard !alreadyExists else { continue }
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

    func addProduction(
        name: String,
        category: ProductionCategory,
        restaurantId: UUID,
        existingProductions: [Production],
        modelContext: ModelContext
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exists = existingProductions.contains {
            $0.restaurantId == restaurantId &&
            $0.categoryId == category.id &&
            normalized($0.name) == normalized(trimmed)
        }
        guard !exists else {
            throw NSError(domain: "ProductionLibraryService", code: 7002, userInfo: [NSLocalizedDescriptionKey: "Produzione già presente in questa categoria."])
        }
        modelContext.insert(
            Production(
                restaurantId: restaurantId,
                name: trimmed,
                categoryId: category.id,
                categoryNameSnapshot: category.name,
                isCustom: true
            )
        )
        try modelContext.save()
    }

    func updateProduction(
        _ production: Production,
        name: String,
        category: ProductionCategory,
        existingProductions: [Production],
        modelContext: ModelContext
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exists = existingProductions.contains {
            $0.id != production.id &&
            $0.restaurantId == production.restaurantId &&
            $0.categoryId == category.id &&
            normalized($0.name) == normalized(trimmed)
        }
        guard !exists else {
            throw NSError(domain: "ProductionLibraryService", code: 7003, userInfo: [NSLocalizedDescriptionKey: "Esiste già una produzione con questo nome nella categoria."])
        }
        production.name = trimmed
        production.categoryId = category.id
        production.categoryNameSnapshot = category.name
        try modelContext.save()
    }

    func deleteProductionIfUnused(
        _ production: Production,
        traceabilityLinks: [TraceabilityLink],
        blastRecords: [BlastChillingRecord],
        modelContext: ModelContext
    ) throws {
        let usedInTraceability = traceabilityLinks.contains { $0.productionId == production.id }
        let usedInBlastChilling = blastRecords.contains { $0.productionId == production.id }
        guard !usedInTraceability && !usedInBlastChilling else {
            throw NSError(domain: "ProductionLibraryService", code: 7004, userInfo: [NSLocalizedDescriptionKey: "Produzione già usata nello storico: non può essere eliminata."])
        }
        modelContext.delete(production)
        try modelContext.save()
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
