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
    var goodsReceipts: [GoodsReceipt] = []
}

@MainActor
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
        data.records = (try? context.fetch(recordDescriptor)) ?? []

        let recordIds = Set(data.records.map(\.id))

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 300
        data.productions = (try? context.fetch(productionDescriptor)) ?? []

        var receiptDescriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\GoodsReceivingRecord.receivedAt, order: .reverse)]
        )
        receiptDescriptor.fetchLimit = recordLimit
        data.goodsReceipts = (try? context.fetch(receiptDescriptor)) ?? []

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
