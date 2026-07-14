//
//  IncomingFoodCatalogDataFetcher.swift
//

import Foundation
import SwiftData

struct IncomingFoodCatalogFetchedData {
    var templates: [ProductTemplate] = []
}

enum IncomingFoodCatalogDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> IncomingFoodCatalogFetchedData {
        let rid = restaurantId
        var data = IncomingFoodCatalogFetchedData()

        var templateDescriptor = FetchDescriptor<ProductTemplate>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ProductTemplate.name)]
        )
        templateDescriptor.fetchLimit = 500
        data.templates = (try? context.fetch(templateDescriptor)) ?? []

        return data
    }

    static func fetchAsync(context: ModelContext, restaurantId: UUID) async -> IncomingFoodCatalogFetchedData {
        await Task.yield()
        return fetch(context: context, restaurantId: restaurantId)
    }
}
