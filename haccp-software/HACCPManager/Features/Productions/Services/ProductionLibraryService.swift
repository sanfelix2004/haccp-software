import Foundation
import SwiftData

struct ProductionLibraryService {
    private static let defaultCategoryNames = [
        "Tutti",
        "Antipasti",
        "Crudi",
        "Primi",
        "Secondi",
        "Contorni",
        "Pane",
        "Salse vegetali",
        "Entrè",
        "Dolci"
    ]

    private static let defaultProductionsByCategory: [String: [String]] = [
        "Antipasti": [
            "Alici", "Baccalà", "Bufala", "Cozze pastellate", "Emulsione cozze",
            "Guancia", "Mozzarella di bufala", "Peperone rosso", "Peperone verde",
            "Polipetti", "Razza", "Triglia"
        ],
        "Crudi": [
            "Astice", "Calamari", "Calamaro", "Gambero bianco", "Gambero rosso di mazzara",
            "Mazzancolle", "Pescatrice", "Pesce spada", "Ricciola",
            "Tartare", "Tonno"
        ],
        "Dolci": [
            "Cheesecake", "Crostata", "Frutta", "Gelato", "Mousse al cioccolato",
            "Panna cotta", "Semifreddo", "Sorbetto", "Tiramisù"
        ],
        "Secondi": [
            "Astice", "Branzino", "Cube roll", "Dentice", "Filetti orata", "Filetto di spigola",
            "Ostriche", "Pagro", "Petto pollo", "Sgombro", "Tonno in nero", "Tonno in panatura nera"
        ],
        "Contorni": ["Cipolla caramellata", "Concasse pomodoro", "Indivia", "Melanzane", "Porro", "Zucchine cotte"],
        "Entrè": ["Cialdella", "Mousse menta curry", "Salsa appetizer"],
        "Pane": ["Pane"],
        "Primi": ["Fonduta pecorino", "Peperone giallo", "Pomodorino", "Ragù polpo", "Tagliatelle"],
        "Salse vegetali": [
            "Acqua cipolla", "Barbabietola", "Carota", "Gazpacho pomodoro", "Lenticchie",
            "Lattughino liquido", "Mayo scapece", "Salsa basilico", "Salsa cicoria",
            "Salsa finocchietto", "Salsa pizzaiola", "Salsa taralli", "Salsa zafferano",
            "Salsa zucca", "Sedano rapa", "Topinambur", "Yogurt"
        ]
    ]

    func ensureDefaults(
        restaurantId: UUID,
        modelContext: ModelContext
    ) {
        guard !catalogIsPopulated(restaurantId: restaurantId, modelContext: modelContext) else { return }
        seedCatalogDefaults(
            restaurantId: restaurantId,
            modelContext: modelContext
        )
    }

    func ensureDefaultsAsync(
        restaurantId: UUID,
        modelContext: ModelContext
    ) async {
        guard !catalogIsPopulated(restaurantId: restaurantId, modelContext: modelContext) else { return }
        await seedCatalogDefaultsAsync(
            restaurantId: restaurantId,
            modelContext: modelContext
        )
    }

    private func catalogIsPopulated(restaurantId: UUID, modelContext: ModelContext) -> Bool {
        let rid = restaurantId
        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        productionDescriptor.fetchLimit = 1
        return !((try? modelContext.fetch(productionDescriptor)) ?? []).isEmpty
    }

    private func seedCatalogDefaults(
        restaurantId: UUID,
        modelContext: ModelContext
    ) {
        let rid = restaurantId
        var scopedCategories = fetchCategories(restaurantId: rid, modelContext: modelContext)
        var didMutate = upsertDefaultCategories(
            restaurantId: restaurantId,
            scopedCategories: &scopedCategories,
            modelContext: modelContext
        )

        if RestaurantModuleBootstrap.shared.claimOnce(
            restaurantId: restaurantId,
            module: "production-catalog-normalize"
        ) {
            didMutate = normalizeExistingProductions(
                restaurantId: restaurantId,
                categories: scopedCategories,
                modelContext: modelContext
            ) || didMutate
        }

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 400
        let scopedProductions = (try? modelContext.fetch(productionDescriptor)) ?? []
        for category in scopedCategories {
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
                        isCustom: false,
                        shelfLifeDays: ProductionShelfLifeDefaults.days(
                            forName: productionName,
                            categoryName: category.name
                        )
                    )
                )
                didMutate = true
            }
        }
        didMutate = backfillShelfLifeDays(restaurantId: restaurantId, modelContext: modelContext) || didMutate
        if didMutate {
            modelContext.saveSafely(operation: "production-catalog-seed")
        }
    }

    private func seedCatalogDefaultsAsync(
        restaurantId: UUID,
        modelContext: ModelContext
    ) async {
        let rid = restaurantId
        var scopedCategories = fetchCategories(restaurantId: rid, modelContext: modelContext)
        var didMutate = upsertDefaultCategories(
            restaurantId: restaurantId,
            scopedCategories: &scopedCategories,
            modelContext: modelContext
        )
        await Task.yield()

        if RestaurantModuleBootstrap.shared.claimOnce(
            restaurantId: restaurantId,
            module: "production-catalog-normalize"
        ) {
            didMutate = normalizeExistingProductions(
                restaurantId: restaurantId,
                categories: scopedCategories,
                modelContext: modelContext
            ) || didMutate
            await Task.yield()
        }

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 400
        let scopedProductions = (try? modelContext.fetch(productionDescriptor)) ?? []
        var insertedCount = 0
        for category in scopedCategories {
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
                        isCustom: false,
                        shelfLifeDays: ProductionShelfLifeDefaults.days(
                            forName: productionName,
                            categoryName: category.name
                        )
                    )
                )
                didMutate = true
                insertedCount += 1
                if insertedCount.isMultiple(of: 12) {
                    await Task.yield()
                }
            }
        }
        didMutate = backfillShelfLifeDays(restaurantId: restaurantId, modelContext: modelContext) || didMutate
        if didMutate {
            modelContext.saveSafely(operation: "production-catalog-seed")
        }
    }

    private func fetchCategories(restaurantId: UUID, modelContext: ModelContext) -> [ProductionCategory] {
        let rid = restaurantId
        var categoryDescriptor = FetchDescriptor<ProductionCategory>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ProductionCategory.orderIndex)]
        )
        categoryDescriptor.fetchLimit = 100
        return (try? modelContext.fetch(categoryDescriptor)) ?? []
    }

    @discardableResult
    private func upsertDefaultCategories(
        restaurantId: UUID,
        scopedCategories: inout [ProductionCategory],
        modelContext: ModelContext
    ) -> Bool {
        var didMutate = false
        if let legacyEntre = scopedCategories.first(where: { normalized($0.name) == "entre" }) {
            legacyEntre.name = "Entrè"
            didMutate = true
        }
        for (index, name) in Self.defaultCategoryNames.enumerated() {
            guard name != "Tutti" else { continue }
            if scopedCategories.contains(where: { normalized($0.name) == normalized(name) }) == false {
                let category = ProductionCategory(restaurantId: restaurantId, name: name, orderIndex: index)
                modelContext.insert(category)
                scopedCategories.append(category)
                didMutate = true
            } else if let category = scopedCategories.first(where: { normalized($0.name) == normalized(name) }) {
                if category.orderIndex != index {
                    category.orderIndex = index
                    didMutate = true
                }
            }
        }
        return didMutate
    }

    @discardableResult
    private func backfillShelfLifeDays(restaurantId: UUID, modelContext: ModelContext) -> Bool {
        let rid = restaurantId
        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        productionDescriptor.fetchLimit = 400
        let scopedProductions = (try? modelContext.fetch(productionDescriptor)) ?? []
        var didMutate = false
        for production in scopedProductions where production.shelfLifeDays == nil {
            production.shelfLifeDays = ProductionShelfLifeDefaults.days(
                forName: production.name,
                categoryName: production.categoryNameSnapshot
            )
            didMutate = true
        }
        return didMutate
    }

    func associate(
        record: TraceabilityRecord,
        production: Production,
        quantityUsed: Double?,
        operatorName: String,
        links: [TraceabilityLink],
        modelContext: ModelContext
    ) throws {
        // Consenti l'associazione se non è scaduto o respinto, ma fai un'eccezione per i lotti non conformi per tracciarne l'utilizzo
        guard record.productStatus != .expired, (record.productStatus != .rejected || record.isNonCompliant) else {
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
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                productionId: production.id,
                actionType: .linkedToProduction,
                operatorName: operatorName,
                detail: production.name
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
        try modelContext.save()
    }

    /// Rimuove un piatto di produzione dall'archivio tracciabilità (lotti restano, senza collegamento).
    func removeProductionGroup(
        group: TraceabilityProductionArchiveGroup,
        records: [TraceabilityRecord],
        links: [TraceabilityLink],
        lottoProductionLinks: [LottoFotoProductionLink],
        productionsById: [UUID: Production],
        modelContext: ModelContext
    ) throws {
        let recordIds = Set(group.ingredients.compactMap(\.recordId))
        let productionId = group.productionId
        let recordsById = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        var deletedLottoLinkIds = Set<UUID>()
        for recordId in recordIds {
            guard let record = recordsById[recordId] else { continue }

            if let lottoId = record.lottoFotoId {
                let matching = lottoProductionLinks.filter { link in
                    link.lottoFotoId == lottoId
                        && link.productionId == productionId
                        && matchesBatch(link.produzioneBatchId, groupBatchId: group.batchId)
                }
                for link in matching {
                    modelContext.delete(link)
                    deletedLottoLinkIds.insert(link.id)
                }
            }
        }

        let remainingLottoLinks = lottoProductionLinks.filter { !deletedLottoLinkIds.contains($0.id) }

        for recordId in recordIds {
            guard let record = recordsById[recordId] else { continue }

            let stillLinkedViaLotto: Bool = {
                guard let lottoId = record.lottoFotoId else { return false }
                return remainingLottoLinks.contains {
                    $0.lottoFotoId == lottoId && $0.productionId == productionId
                }
            }()

            guard !stillLinkedViaLotto else { continue }

            links
                .filter { $0.receivedItemId == recordId && $0.productionId == productionId }
                .forEach { modelContext.delete($0) }

            let remainingProductionIds = Set(
                links
                    .filter { $0.receivedItemId == recordId && $0.productionId != productionId }
                    .map(\.productionId)
            )
            let names = remainingProductionIds
                .compactMap { productionsById[$0]?.name }
                .sorted()
            record.productionReference = names.isEmpty ? nil : names.joined(separator: ", ")
        }

        try modelContext.save()
    }

    private func matchesBatch(_ linkBatchId: UUID?, groupBatchId: UUID?) -> Bool {
        guard let groupBatchId else { return linkBatchId == nil }
        return linkBatchId == groupBatchId
    }

    func addProduction(
        name: String,
        category: ProductionCategory,
        restaurantId: UUID,
        existingProductions: [Production],
        modelContext: ModelContext,
        shelfLifeDays: Int? = nil
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
                isCustom: true,
                shelfLifeDays: shelfLifeDays
            )
        )
        try modelContext.save()
    }

    func updateProduction(
        _ production: Production,
        name: String,
        category: ProductionCategory,
        existingProductions: [Production],
        modelContext: ModelContext,
        shelfLifeDays: Int? = nil
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
        production.shelfLifeDays = shelfLifeDays
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

    @discardableResult
    private func normalizeExistingProductions(
        restaurantId: UUID,
        categories: [ProductionCategory],
        modelContext: ModelContext
    ) -> Bool {
        var categoryByName: [String: ProductionCategory] = [:]
        for category in categories {
            categoryByName[normalized(category.name)] = category
        }
        let rid = restaurantId
        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        productionDescriptor.fetchLimit = 400
        let scopedProductions = (try? modelContext.fetch(productionDescriptor)) ?? []
        guard !scopedProductions.isEmpty else { return false }

        var blastDescriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        blastDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        let blastRecords = (try? modelContext.fetch(blastDescriptor)) ?? []

        var linkDescriptor = FetchDescriptor<TraceabilityLink>()
        linkDescriptor.fetchLimit = 2_000
        let productionIds = Set(scopedProductions.map(\.id))
        let traceabilityLinks = ((try? modelContext.fetch(linkDescriptor)) ?? [])
            .filter { productionIds.contains($0.productionId) }

        var didMutate = false
        for production in scopedProductions {
            let currentCategoryName = categories.first(where: { $0.id == production.categoryId })?.name
                ?? production.categoryNameSnapshot
            guard
                let targetCategoryName = correctedCategoryName(for: production.name, currentCategoryName: currentCategoryName),
                let targetCategory = categoryByName[normalized(targetCategoryName)]
            else { continue }

            if let duplicate = scopedProductions.first(where: {
                $0.id != production.id &&
                $0.categoryId == targetCategory.id &&
                normalized($0.name) == normalized(production.name)
            }) {
                if isProductionUsed(production, traceabilityLinks: traceabilityLinks, blastRecords: blastRecords) == false {
                    modelContext.delete(production)
                    didMutate = true
                    continue
                }
                if isProductionUsed(duplicate, traceabilityLinks: traceabilityLinks, blastRecords: blastRecords) == false {
                    modelContext.delete(duplicate)
                    didMutate = true
                }
            }

            if production.categoryId != targetCategory.id
                || production.categoryNameSnapshot != targetCategory.name {
                production.categoryId = targetCategory.id
                production.categoryNameSnapshot = targetCategory.name
                didMutate = true
            }
        }
        return didMutate
    }

    private func correctedCategoryName(for productionName: String, currentCategoryName: String) -> String? {
        let current = normalized(currentCategoryName)
        let name = simplifiedProductionName(productionName)
        if current == normalized("Dolci") {
            let secondi = [
                "astice", "branzino", "cuberoll", "dentice", "filettiorata", "filettodispigola",
                "ostriche", "pagro", "pescatrice", "pescespada", "ricciola", "sgombro",
                "tonno", "tonnoinnero", "tonnoinpanaturanera"
            ]
            if secondi.contains(name) {
                return "Secondi"
            }
        }
        if current == normalized("Crudi"), name == "tagliatelle" {
            return "Primi"
        }
        return nil
    }

    private func simplifiedProductionName(_ value: String) -> String {
        normalized(value)
            .filter { $0.isLetter }
    }

    private func isProductionUsed(
        _ production: Production,
        traceabilityLinks: [TraceabilityLink],
        blastRecords: [BlastChillingRecord]
    ) -> Bool {
        traceabilityLinks.contains { $0.productionId == production.id } ||
        blastRecords.contains { $0.productionId == production.id }
    }
}
