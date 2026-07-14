//
//  OilControlDataFetcher.swift
//

import Foundation
import SwiftData

struct OilControlFetchedData {
    var points: [OilPoint] = []
    var records: [OilControlRecord] = []
    var alerts: [OilControlAlert] = []
}

enum OilControlDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> OilControlFetchedData {
        let rid = restaurantId
        var data = OilControlFetchedData()

        var pointDescriptor = FetchDescriptor<OilPoint>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\OilPoint.name)]
        )
        pointDescriptor.fetchLimit = 50
        data.points = (try? context.fetch(pointDescriptor)) ?? []

        var recordDescriptor = FetchDescriptor<OilControlRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\OilControlRecord.checkedAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        data.records = (try? context.fetch(recordDescriptor)) ?? []

        var alertDescriptor = FetchDescriptor<OilControlAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive },
            sortBy: [SortDescriptor(\OilControlAlert.createdAt, order: .reverse)]
        )
        alertDescriptor.fetchLimit = 100
        data.alerts = (try? context.fetch(alertDescriptor)) ?? []

        return data
    }
}
