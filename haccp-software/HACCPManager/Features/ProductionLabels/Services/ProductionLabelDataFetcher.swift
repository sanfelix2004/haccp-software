//
//  ProductionLabelDataFetcher.swift
//  Fetch mirati — nessun @Query globale.
//

import Foundation
import SwiftData

struct ProductionLabelFetchedData {
    var labels: [ProductionLabelRecord] = []
    var traceabilityRecords: [TraceabilityRecord] = []
    var goodsReceipts: [GoodsReceivingRecord] = []
    var blastRecords: [BlastChillingRecord] = []
    var defrostRecords: [DefrostRecord] = []
    var productions: [Production] = []
}

@MainActor
enum ProductionLabelDataFetcher {

    static let labelLimit = 600
    static let sourcePickerLimit = 120

    static func fetch(context: ModelContext, restaurantId: UUID, includeArchived: Bool) -> ProductionLabelFetchedData {
        let rid = restaurantId
        var data = ProductionLabelFetchedData()

        if includeArchived {
            var descriptor = FetchDescriptor<ProductionLabelRecord>(
                predicate: #Predicate { $0.restaurantId == rid },
                sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = labelLimit
            data.labels = (try? context.fetch(descriptor)) ?? []
        } else {
            var descriptor = FetchDescriptor<ProductionLabelRecord>(
                predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
                sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = labelLimit
            data.labels = (try? context.fetch(descriptor)) ?? []
        }

        var traceDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.createdAt, order: .reverse)]
        )
        traceDescriptor.fetchLimit = sourcePickerLimit
        data.traceabilityRecords = (try? context.fetch(traceDescriptor)) ?? []

        var goodsDescriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\GoodsReceivingRecord.receivedAt, order: .reverse)]
        )
        goodsDescriptor.fetchLimit = sourcePickerLimit
        data.goodsReceipts = (try? context.fetch(goodsDescriptor)) ?? []

        var blastDescriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\BlastChillingRecord.startedAt, order: .reverse)]
        )
        blastDescriptor.fetchLimit = sourcePickerLimit
        data.blastRecords = (try? context.fetch(blastDescriptor)) ?? []

        var defrostDescriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived && $0.endAt != nil },
            sortBy: [SortDescriptor(\DefrostRecord.startAt, order: .reverse)]
        )
        defrostDescriptor.fetchLimit = sourcePickerLimit
        data.defrostRecords = (try? context.fetch(defrostDescriptor)) ?? []

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 200
        data.productions = (try? context.fetch(productionDescriptor)) ?? []

        return data
    }
}
