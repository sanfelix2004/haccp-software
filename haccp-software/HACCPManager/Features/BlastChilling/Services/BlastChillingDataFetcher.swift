//
//  BlastChillingDataFetcher.swift
//

import Foundation
import SwiftData

struct BlastChillingFetchedData {
    var records: [BlastChillingRecord] = []
    var productionLabels: [ProductionLabelRecord] = []
    var categories: [ProductionCategory] = []
    var productions: [Production] = []
}

enum BlastChillingDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> BlastChillingFetchedData {
        let rid = restaurantId
        var data = BlastChillingFetchedData()

        var recordDescriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\BlastChillingRecord.createdAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        data.records = (try? context.fetch(recordDescriptor)) ?? []

        var labelDescriptor = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse)]
        )
        labelDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        data.productionLabels = (try? context.fetch(labelDescriptor)) ?? []

        var categoryDescriptor = FetchDescriptor<ProductionCategory>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ProductionCategory.orderIndex)]
        )
        categoryDescriptor.fetchLimit = 100
        data.categories = (try? context.fetch(categoryDescriptor)) ?? []

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 300
        data.productions = (try? context.fetch(productionDescriptor)) ?? []

        return data
    }
}
