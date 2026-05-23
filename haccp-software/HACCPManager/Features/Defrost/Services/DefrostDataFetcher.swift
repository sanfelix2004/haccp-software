//
//  DefrostDataFetcher.swift
//

import Foundation
import SwiftData

struct DefrostFetchedData {
    var records: [DefrostRecord] = []
    var criticalities: [DefrostCriticality] = []
    var traceabilityRecords: [TraceabilityRecord] = []
}

@MainActor
enum DefrostDataFetcher {

    static let recordLimit = 500
    static let traceabilityLimit = 150

    static func fetch(context: ModelContext, restaurantId: UUID) -> DefrostFetchedData {
        let rid = restaurantId
        var data = DefrostFetchedData()

        var recordDescriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\DefrostRecord.startAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = recordLimit
        data.records = (try? context.fetch(recordDescriptor)) ?? []

        var critDescriptor = FetchDescriptor<DefrostCriticality>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\DefrostCriticality.createdAt, order: .reverse)]
        )
        critDescriptor.fetchLimit = recordLimit
        data.criticalities = (try? context.fetch(critDescriptor)) ?? []

        var traceDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.createdAt, order: .reverse)]
        )
        traceDescriptor.fetchLimit = traceabilityLimit
        data.traceabilityRecords = (try? context.fetch(traceDescriptor)) ?? []

        return data
    }
}
