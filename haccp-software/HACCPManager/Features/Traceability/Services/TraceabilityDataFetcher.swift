//
//  TraceabilityDataFetcher.swift
//  Fetch mirati per ristorante (solo dati attivi).
//

import Foundation
import SwiftData

struct TraceabilityFetchedData {
    var records: [TraceabilityRecord] = []
    var productions: [Production] = []
    var links: [TraceabilityLink] = []
    var logs: [TraceabilityLog] = []
    var images: [ProductImage] = []
    var defrostRecords: [DefrostRecord] = []
    var lottoFotos: [LottoFoto] = []
    var lottoProductionLinks: [LottoFotoProductionLink] = []
}

enum TraceabilityDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> TraceabilityFetchedData {
        let rid = restaurantId

        let recordLimit = PerformanceConfig.traceabilityActiveFetchLimit

        var data = TraceabilityFetchedData()
        var recordDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.createdAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = recordLimit
        let fetched = (try? context.fetch(recordDescriptor)) ?? []
        // Esclude batch produzione finiti (restano collegati via produzioneBatchId).
        data.records = fetched.filter { $0.produzioneBatchId == nil }
        var didMigratePartialStatus = false
        for record in data.records where record.productStatusRaw == "PARTIALLY_USED" {
            record.productStatusRaw = ProductStatus.available.rawValue
            didMigratePartialStatus = true
        }
        if didMigratePartialStatus {
            context.saveSafely(operation: "traceability-status-migration")
        }

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 300
        data.productions = (try? context.fetch(productionDescriptor)) ?? []

        var lottoDescriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\LottoFoto.dataScatto, order: .reverse)]
        )
        lottoDescriptor.fetchLimit = recordLimit * 2
        data.lottoFotos = ((try? context.fetch(lottoDescriptor)) ?? []).filter(\.isConfirmed)

        data.lottoProductionLinks = ((try? context.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? [])
            .filter { link in
                data.lottoFotos.contains(where: { $0.id == link.lottoFotoId })
            }

        let recordIds = Set(data.records.map(\.id))

        var defrostDescriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\DefrostRecord.startAt, order: .reverse)]
        )
        defrostDescriptor.fetchLimit = 200
        data.defrostRecords = (try? context.fetch(defrostDescriptor)) ?? []

        guard !recordIds.isEmpty else { return data }

        var linkDescriptor = FetchDescriptor<TraceabilityLink>()
        linkDescriptor.fetchLimit = recordLimit * 4
        data.links = ((try? context.fetch(linkDescriptor)) ?? []).filter { recordIds.contains($0.receivedItemId) }

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
        data.images = ((try? context.fetch(imageDescriptor)) ?? []).filter { recordIds.contains($0.receivedItemId) }

        return data
    }
}
