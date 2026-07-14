//
//  ProductionCatalogDataFetcher.swift
//

import Foundation
import SwiftData

struct ProductionCatalogFetchedData {
    var categories: [ProductionCategory] = []
    var productions: [Production] = []
}

enum ProductionCatalogDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> ProductionCatalogFetchedData {
        let rid = restaurantId
        var data = ProductionCatalogFetchedData()

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
        productionDescriptor.fetchLimit = 400
        data.productions = (try? context.fetch(productionDescriptor)) ?? []

        return data
    }

    static func fetchAsync(context: ModelContext, restaurantId: UUID) async -> ProductionCatalogFetchedData {
        await MainThreadYield.betweenFetchPhases()
        let rid = restaurantId
        var data = ProductionCatalogFetchedData()

        var categoryDescriptor = FetchDescriptor<ProductionCategory>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ProductionCategory.orderIndex)]
        )
        categoryDescriptor.fetchLimit = 100
        data.categories = (try? context.fetch(categoryDescriptor)) ?? []
        await MainThreadYield.betweenFetchPhases()

        var productionDescriptor = FetchDescriptor<Production>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Production.name)]
        )
        productionDescriptor.fetchLimit = 400
        data.productions = (try? context.fetch(productionDescriptor)) ?? []

        return data
    }
}
