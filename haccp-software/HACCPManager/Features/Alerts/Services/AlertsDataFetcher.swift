//
//  AlertsDataFetcher.swift
//

import Foundation
import SwiftData

struct AlertsFetchedData {
    var checklistAlerts: [ChecklistAlert] = []
    var temperatureAlerts: [TemperatureAlert] = []
    var cleaningCriticalities: [CleaningCriticality] = []
    var oilAlerts: [OilControlAlert] = []
    var defrostCriticalities: [DefrostCriticality] = []
    var traceabilityRecords: [TraceabilityRecord] = []
    var goodsReceipts: [GoodsReceivingRecord] = []
    var productionLabels: [ProductionLabelRecord] = []
}

enum AlertsDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> AlertsFetchedData {
        let rid = restaurantId
        var data = AlertsFetchedData()

        var checklistDescriptor = FetchDescriptor<ChecklistAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive },
            sortBy: [SortDescriptor(\ChecklistAlert.createdAt, order: .reverse)]
        )
        checklistDescriptor.fetchLimit = PerformanceConfig.checklistAlertFetchLimit
        data.checklistAlerts = (try? context.fetch(checklistDescriptor)) ?? []

        var temperatureDescriptor = FetchDescriptor<TemperatureAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive },
            sortBy: [SortDescriptor(\TemperatureAlert.createdAt, order: .reverse)]
        )
        temperatureDescriptor.fetchLimit = 200
        data.temperatureAlerts = (try? context.fetch(temperatureDescriptor)) ?? []

        var cleaningDescriptor = FetchDescriptor<CleaningCriticality>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isResolved },
            sortBy: [SortDescriptor(\CleaningCriticality.createdAt, order: .reverse)]
        )
        cleaningDescriptor.fetchLimit = PerformanceConfig.checklistCleaningCriticalityFetchLimit
        data.cleaningCriticalities = (try? context.fetch(cleaningDescriptor)) ?? []

        var oilDescriptor = FetchDescriptor<OilControlAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive },
            sortBy: [SortDescriptor(\OilControlAlert.createdAt, order: .reverse)]
        )
        oilDescriptor.fetchLimit = 100
        data.oilAlerts = (try? context.fetch(oilDescriptor)) ?? []

        var defrostDescriptor = FetchDescriptor<DefrostCriticality>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isResolved },
            sortBy: [SortDescriptor(\DefrostCriticality.createdAt, order: .reverse)]
        )
        defrostDescriptor.fetchLimit = 100
        data.defrostCriticalities = (try? context.fetch(defrostDescriptor)) ?? []

        var traceDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.expiryDate)]
        )
        traceDescriptor.fetchLimit = PerformanceConfig.traceabilityActiveFetchLimit
        data.traceabilityRecords = (try? context.fetch(traceDescriptor)) ?? []

        var goodsDescriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\GoodsReceivingRecord.createdAt, order: .reverse)]
        )
        goodsDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        data.goodsReceipts = (try? context.fetch(goodsDescriptor)) ?? []

        var labelDescriptor = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse)]
        )
        labelDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        data.productionLabels = (try? context.fetch(labelDescriptor)) ?? []

        return data
    }
}
