//
//  IncomingFoodCatalogDataFetcher.swift
//

import Foundation
import SwiftData

struct IncomingFoodCatalogFetchedData {
    var templates: [ProductTemplate] = []
    var categories: [IncomingFoodCategory] = []
}

enum IncomingFoodCatalogDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> IncomingFoodCatalogFetchedData {
        let rid = restaurantId
        var data = IncomingFoodCatalogFetchedData()

        ProductTemplateCatalogService().ensureCategories(
            restaurantId: restaurantId,
            modelContext: context
        )

        var templateDescriptor = FetchDescriptor<ProductTemplate>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ProductTemplate.name)]
        )
        templateDescriptor.fetchLimit = 500
        data.templates = (try? context.fetch(templateDescriptor)) ?? []

        var categoryDescriptor = FetchDescriptor<IncomingFoodCategory>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\IncomingFoodCategory.orderIndex)]
        )
        categoryDescriptor.fetchLimit = 200
        data.categories = (try? context.fetch(categoryDescriptor)) ?? []

        return data
    }

    static func fetchAsync(context: ModelContext, restaurantId: UUID) async -> IncomingFoodCatalogFetchedData {
        await Task.yield()
        return fetch(context: context, restaurantId: restaurantId)
    }
}
