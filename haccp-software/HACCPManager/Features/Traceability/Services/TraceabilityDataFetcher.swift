//
//  TraceabilityDataFetcher.swift
//  Fetch mirati per ristorante (solo dati attivi).
//

import Foundation
import SwiftData

struct TraceabilityFetchedData {
    var records: [TraceabilityRecord] = []
    /// Record piatto finito (con foto produzione) — non mostrati come lotti in ingresso.
    var productionOutputRecords: [TraceabilityRecord] = []
    var productions: [Production] = []
    var links: [TraceabilityLink] = []
    var logs: [TraceabilityLog] = []
    var images: [ProductImage] = []
    var defrostRecords: [DefrostRecord] = []
    var lottoFotos: [LottoFoto] = []
    var lottoProductionLinks: [LottoFotoProductionLink] = []
    var batches: [ProduzioneBatch] = []
    var ingredientiTracciati: [IngredienteTracciato] = []
}

enum TraceabilityDataFetcher {

    /// Fetch con yield tra le fasi per cedere frame UI durante reload.
    static func fetchAsync(context: ModelContext, restaurantId: UUID) async -> TraceabilityFetchedData {
        let rid = restaurantId
        let recordLimit = PerformanceConfig.traceabilityActiveFetchLimit
        var data = TraceabilityFetchedData()

        var recordDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.createdAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = recordLimit
        let fetched = (try? context.fetch(recordDescriptor)) ?? []
        data.records = fetched.filter { $0.produzioneBatchId == nil }
        var didMigratePartialStatus = false
        for record in data.records where record.productStatusRaw == "PARTIALLY_USED" {
            record.productStatusRaw = ProductStatus.available.rawValue
            didMigratePartialStatus = true
        }
        if didMigratePartialStatus {
            context.saveSafely(operation: "traceability-status-migration")
        }
        await Task.yield()

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 300
        data.productions = (try? context.fetch(productionDescriptor)) ?? []
        let productionIds = Set(data.productions.map(\.id))

        var batchDescriptor = FetchDescriptor<ProduzioneBatch>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\ProduzioneBatch.producedAt, order: .reverse)]
        )
        batchDescriptor.fetchLimit = 300
        data.batches = (try? context.fetch(batchDescriptor)) ?? []
        let batchIds = Set(data.batches.map(\.id))
        data.productionOutputRecords = fetched.filter { record in
            guard let batchId = record.produzioneBatchId else { return false }
            return batchIds.contains(batchId)
        }
        await Task.yield()

        var trackedDescriptor = FetchDescriptor<IngredienteTracciato>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\IngredienteTracciato.sequenceIndex)]
        )
        trackedDescriptor.fetchLimit = 1200
        data.ingredientiTracciati = ((try? context.fetch(trackedDescriptor)) ?? [])
            .filter { batchIds.contains($0.produzioneBatchId) }

        var lottoDescriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\LottoFoto.dataScatto, order: .reverse)]
        )
        lottoDescriptor.fetchLimit = recordLimit * 2
        data.lottoFotos = ((try? context.fetch(lottoDescriptor)) ?? []).filter(\.isConfirmed)

        let lottoFotoIds = Set(data.lottoFotos.map(\.id))
        data.lottoProductionLinks = ((try? context.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? [])
            .filter { link in
                productionIds.contains(link.productionId) || lottoFotoIds.contains(link.lottoFotoId)
            }
        await Task.yield()

        var recordIds = Set(data.records.map(\.id))

        var defrostDescriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\DefrostRecord.startAt, order: .reverse)]
        )
        defrostDescriptor.fetchLimit = 200
        data.defrostRecords = (try? context.fetch(defrostDescriptor)) ?? []

        var linkDescriptor = FetchDescriptor<TraceabilityLink>()
        linkDescriptor.fetchLimit = recordLimit * 4
        data.links = ((try? context.fetch(linkDescriptor)) ?? []).filter { link in
            recordIds.contains(link.receivedItemId) || productionIds.contains(link.productionId)
        }

        let linkedRecordIds = Set(data.links.map(\.receivedItemId))
        let missingRecordIds = linkedRecordIds.subtracting(recordIds)
        if !missingRecordIds.isEmpty {
            var supplementalDescriptor = FetchDescriptor<TraceabilityRecord>(
                predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
                sortBy: [SortDescriptor(\TraceabilityRecord.createdAt, order: .reverse)]
            )
            supplementalDescriptor.fetchLimit = recordLimit
            let supplemental = ((try? context.fetch(supplementalDescriptor)) ?? [])
                .filter { missingRecordIds.contains($0.id) && $0.produzioneBatchId == nil }
            data.records.append(contentsOf: supplemental)
            recordIds.formUnion(supplemental.map(\.id))
        }
        await Task.yield()

        guard !recordIds.isEmpty else { return data }

        var logDescriptor = FetchDescriptor<TraceabilityLog>(
            sortBy: [SortDescriptor(\TraceabilityLog.timestamp, order: .reverse)]
        )
        logDescriptor.fetchLimit = recordLimit * 2
        data.logs = ((try? context.fetch(logDescriptor)) ?? []).filter { recordIds.contains($0.receivedItemId) }

        var imageDescriptor = FetchDescriptor<ProductImage>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\ProductImage.createdAt, order: .reverse)]
        )
        imageDescriptor.fetchLimit = recordLimit * 2
        // Include foto piatto (productionDish) legate al batch anche se receivedItemId
        // punta al record produzione finita (escluso dai lotti in ingresso).
        data.images = ((try? context.fetch(imageDescriptor)) ?? []).filter { image in
            if let batchId = image.produzioneBatchId, batchIds.contains(batchId) {
                return true
            }
            if let rid = image.receivedItemId {
                return recordIds.contains(rid)
            }
            return false
        }

        return data
    }
}
