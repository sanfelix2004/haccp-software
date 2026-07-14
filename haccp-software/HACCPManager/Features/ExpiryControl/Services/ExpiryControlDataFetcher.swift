//
//  ExpiryControlDataFetcher.swift
//

import Foundation
import SwiftData

struct ExpiryControlFetchedData {
    var records: [TraceabilityRecord] = []
    var lottoFotos: [LottoFoto] = []
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

        return data
    }
}
