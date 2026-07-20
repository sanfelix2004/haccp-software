//
//  ExpiryControlDataFetcher.swift
//

import Foundation
import SwiftData

struct ExpiryControlFetchedData {
    var records: [TraceabilityRecord] = []
    var lottoFotos: [LottoFoto] = []
    var productImages: [ProductImage] = []
}

enum ExpiryControlDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> ExpiryControlFetchedData {
        let rid = restaurantId
        var data = ExpiryControlFetchedData()

        var recordDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.expiryDate)]
        )
        recordDescriptor.fetchLimit = PerformanceConfig.traceabilityActiveFetchLimit
        data.records = (try? context.fetch(recordDescriptor)) ?? []

        var lottoDescriptor = FetchDescriptor<LottoFoto>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\LottoFoto.dataScatto, order: .reverse)]
        )
        lottoDescriptor.fetchLimit = PerformanceConfig.traceabilityActiveFetchLimit
        data.lottoFotos = (try? context.fetch(lottoDescriptor)) ?? []

        let recordIds = Set(data.records.map(\.id))
        let batchIds = Set(data.records.compactMap(\.produzioneBatchId))
        var imageDescriptor = FetchDescriptor<ProductImage>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\ProductImage.createdAt, order: .reverse)]
        )
        imageDescriptor.fetchLimit = PerformanceConfig.traceabilityActiveFetchLimit * 2
        data.productImages = ((try? context.fetch(imageDescriptor)) ?? []).filter { image in
            if let rid = image.receivedItemId, recordIds.contains(rid) { return true }
            if let batchId = image.produzioneBatchId, batchIds.contains(batchId) { return true }
            return false
        }

        return data
    }
}
