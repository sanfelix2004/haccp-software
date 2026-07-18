//
//  GoodsReceivingDataFetcher.swift
//

import Foundation
import SwiftData

struct GoodsReceivingFetchedData {
    var records: [GoodsReceipt] = []
    var suppliers: [Supplier] = []
    var templates: [ProductTemplate] = []
    var productImages: [ProductImage] = []
}

enum GoodsReceivingDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> GoodsReceivingFetchedData {
        let rid = restaurantId
        var data = GoodsReceivingFetchedData()

        var recordDescriptor = FetchDescriptor<GoodsReceipt>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\GoodsReceipt.createdAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        data.records = (try? context.fetch(recordDescriptor)) ?? []

        var supplierDescriptor = FetchDescriptor<Supplier>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\Supplier.createdAt, order: .reverse)]
        )
        supplierDescriptor.fetchLimit = 200
        data.suppliers = (try? context.fetch(supplierDescriptor)) ?? []

        var templateDescriptor = FetchDescriptor<ProductTemplate>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ProductTemplate.name)]
        )
        templateDescriptor.fetchLimit = 400
        data.templates = (try? context.fetch(templateDescriptor)) ?? []

        let recordIds = Set(data.records.map(\.id))
        guard !recordIds.isEmpty else { return data }

        var imageDescriptor = FetchDescriptor<ProductImage>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\ProductImage.createdAt, order: .reverse)]
        )
        imageDescriptor.fetchLimit = 400
        data.productImages = ((try? context.fetch(imageDescriptor)) ?? [])
            .filter { image in
                guard let rid = image.receivedItemId else { return false }
                return recordIds.contains(rid)
            }

        return data
    }
}
