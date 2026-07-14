//
//  AnalyticsDataFetcher.swift
//  Campioni limitati per grafici — evita @Query globali in AnalyticsView.
//

import Foundation
import SwiftData

struct AnalyticsFetchedData {
    var checklistRuns: [ChecklistRun] = []
    var checklistResults: [ChecklistItemResult] = []
    var checklistAlerts: [ChecklistAlert] = []
    var temperatureRecords: [TemperatureRecord] = []
    var temperatureDevices: [TemperatureDevice] = []
    var cleaningRecords: [CleaningRecord] = []
    var cleaningCriticalities: [CleaningCriticality] = []
    var blastRecords: [BlastChillingRecord] = []
    var defrostRecords: [DefrostRecord] = []
    var oilRecords: [OilControlRecord] = []
    var goodsRecords: [GoodsReceivingRecord] = []
    var traceabilityRecords: [TraceabilityRecord] = []
    var labelRecords: [ProductionLabelRecord] = []
}

enum AnalyticsDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> AnalyticsFetchedData {
        fetchSync(context: context, restaurantId: restaurantId)
    }

    static func fetchAsync(context: ModelContext, restaurantId: UUID) async -> AnalyticsFetchedData {
        var data = AnalyticsFetchedData()
        let rid = restaurantId
        let since = AnalyticsPeriod.thirtyDays.startDate()
        let seriesLimit = PerformanceConfig.analyticsSeriesFetchLimit

        var runDescriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { $0.restaurantId == rid && $0.startedAt >= since },
            sortBy: [SortDescriptor(\ChecklistRun.startedAt, order: .reverse)]
        )
        runDescriptor.fetchLimit = PerformanceConfig.checklistRunFetchLimit
        data.checklistRuns = (try? context.fetch(runDescriptor)) ?? []

        let runIds = Set(data.checklistRuns.map(\.id))
        data.checklistResults = fetchChecklistItemResults(context, runIds: runIds)
        await Task.yield()

        var alertDescriptor = FetchDescriptor<ChecklistAlert>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ChecklistAlert.createdAt, order: .reverse)]
        )
        alertDescriptor.fetchLimit = PerformanceConfig.checklistAlertFetchLimit
        data.checklistAlerts = (try? context.fetch(alertDescriptor)) ?? []

        var tempDescriptor = FetchDescriptor<TemperatureRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.measuredAt >= since },
            sortBy: [SortDescriptor(\TemperatureRecord.measuredAt, order: .reverse)]
        )
        tempDescriptor.fetchLimit = seriesLimit
        data.temperatureRecords = (try? context.fetch(tempDescriptor)) ?? []

        var deviceDescriptor = FetchDescriptor<TemperatureDevice>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\TemperatureDevice.name)]
        )
        deviceDescriptor.fetchLimit = 100
        data.temperatureDevices = (try? context.fetch(deviceDescriptor)) ?? []
        await Task.yield()

        var cleaningDescriptor = FetchDescriptor<CleaningRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.updatedAt >= since },
            sortBy: [SortDescriptor(\CleaningRecord.updatedAt, order: .reverse)]
        )
        cleaningDescriptor.fetchLimit = seriesLimit
        data.cleaningRecords = (try? context.fetch(cleaningDescriptor)) ?? []

        var criticalityDescriptor = FetchDescriptor<CleaningCriticality>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningCriticality.createdAt, order: .reverse)]
        )
        criticalityDescriptor.fetchLimit = PerformanceConfig.checklistCleaningCriticalityFetchLimit
        data.cleaningCriticalities = (try? context.fetch(criticalityDescriptor)) ?? []
        await Task.yield()

        var blastDescriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.startedAt >= since },
            sortBy: [SortDescriptor(\BlastChillingRecord.startedAt, order: .reverse)]
        )
        blastDescriptor.fetchLimit = seriesLimit
        data.blastRecords = (try? context.fetch(blastDescriptor)) ?? []

        var defrostDescriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.startAt >= since },
            sortBy: [SortDescriptor(\DefrostRecord.startAt, order: .reverse)]
        )
        defrostDescriptor.fetchLimit = seriesLimit
        data.defrostRecords = (try? context.fetch(defrostDescriptor)) ?? []
        await Task.yield()

        var oilDescriptor = FetchDescriptor<OilControlRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.checkedAt >= since },
            sortBy: [SortDescriptor(\OilControlRecord.checkedAt, order: .reverse)]
        )
        oilDescriptor.fetchLimit = seriesLimit
        data.oilRecords = (try? context.fetch(oilDescriptor)) ?? []

        var goodsDescriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.receivedAt >= since },
            sortBy: [SortDescriptor(\GoodsReceivingRecord.receivedAt, order: .reverse)]
        )
        goodsDescriptor.fetchLimit = seriesLimit
        data.goodsRecords = (try? context.fetch(goodsDescriptor)) ?? []
        await Task.yield()

        var traceDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.expiryDate)]
        )
        traceDescriptor.fetchLimit = PerformanceConfig.analyticsTraceabilitySnapshotLimit
        data.traceabilityRecords = (try? context.fetch(traceDescriptor)) ?? []

        var labelDescriptor = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.createdAt >= since },
            sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse)]
        )
        labelDescriptor.fetchLimit = seriesLimit
        data.labelRecords = (try? context.fetch(labelDescriptor)) ?? []

        return data
    }

    private static func fetchSync(context: ModelContext, restaurantId: UUID) -> AnalyticsFetchedData {
        let rid = restaurantId
        let since = AnalyticsPeriod.thirtyDays.startDate()
        let seriesLimit = PerformanceConfig.analyticsSeriesFetchLimit
        var data = AnalyticsFetchedData()

        var runDescriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { $0.restaurantId == rid && $0.startedAt >= since },
            sortBy: [SortDescriptor(\ChecklistRun.startedAt, order: .reverse)]
        )
        runDescriptor.fetchLimit = PerformanceConfig.checklistRunFetchLimit
        data.checklistRuns = (try? context.fetch(runDescriptor)) ?? []

        let runIds = Set(data.checklistRuns.map(\.id))
        data.checklistResults = fetchChecklistItemResults(context, runIds: runIds)

        var alertDescriptor = FetchDescriptor<ChecklistAlert>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ChecklistAlert.createdAt, order: .reverse)]
        )
        alertDescriptor.fetchLimit = PerformanceConfig.checklistAlertFetchLimit
        data.checklistAlerts = (try? context.fetch(alertDescriptor)) ?? []

        var tempDescriptor = FetchDescriptor<TemperatureRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.measuredAt >= since },
            sortBy: [SortDescriptor(\TemperatureRecord.measuredAt, order: .reverse)]
        )
        tempDescriptor.fetchLimit = seriesLimit
        data.temperatureRecords = (try? context.fetch(tempDescriptor)) ?? []

        var deviceDescriptor = FetchDescriptor<TemperatureDevice>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\TemperatureDevice.name)]
        )
        deviceDescriptor.fetchLimit = 100
        data.temperatureDevices = (try? context.fetch(deviceDescriptor)) ?? []

        var cleaningDescriptor = FetchDescriptor<CleaningRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.updatedAt >= since },
            sortBy: [SortDescriptor(\CleaningRecord.updatedAt, order: .reverse)]
        )
        cleaningDescriptor.fetchLimit = seriesLimit
        data.cleaningRecords = (try? context.fetch(cleaningDescriptor)) ?? []

        var criticalityDescriptor = FetchDescriptor<CleaningCriticality>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningCriticality.createdAt, order: .reverse)]
        )
        criticalityDescriptor.fetchLimit = PerformanceConfig.checklistCleaningCriticalityFetchLimit
        data.cleaningCriticalities = (try? context.fetch(criticalityDescriptor)) ?? []

        var blastDescriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.startedAt >= since },
            sortBy: [SortDescriptor(\BlastChillingRecord.startedAt, order: .reverse)]
        )
        blastDescriptor.fetchLimit = seriesLimit
        data.blastRecords = (try? context.fetch(blastDescriptor)) ?? []

        var defrostDescriptor = FetchDescriptor<DefrostRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.startAt >= since },
            sortBy: [SortDescriptor(\DefrostRecord.startAt, order: .reverse)]
        )
        defrostDescriptor.fetchLimit = seriesLimit
        data.defrostRecords = (try? context.fetch(defrostDescriptor)) ?? []

        var oilDescriptor = FetchDescriptor<OilControlRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.checkedAt >= since },
            sortBy: [SortDescriptor(\OilControlRecord.checkedAt, order: .reverse)]
        )
        oilDescriptor.fetchLimit = seriesLimit
        data.oilRecords = (try? context.fetch(oilDescriptor)) ?? []

        var goodsDescriptor = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.receivedAt >= since },
            sortBy: [SortDescriptor(\GoodsReceivingRecord.receivedAt, order: .reverse)]
        )
        goodsDescriptor.fetchLimit = seriesLimit
        data.goodsRecords = (try? context.fetch(goodsDescriptor)) ?? []

        var traceDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\TraceabilityRecord.expiryDate)]
        )
        traceDescriptor.fetchLimit = PerformanceConfig.analyticsTraceabilitySnapshotLimit
        data.traceabilityRecords = (try? context.fetch(traceDescriptor)) ?? []

        var labelDescriptor = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.createdAt >= since },
            sortBy: [SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse)]
        )
        labelDescriptor.fetchLimit = seriesLimit
        data.labelRecords = (try? context.fetch(labelDescriptor)) ?? []

        return data
    }

    private static func fetchChecklistItemResults(
        _ context: ModelContext,
        runIds: Set<UUID>
    ) -> [ChecklistItemResult] {
        guard !runIds.isEmpty else { return [] }
        var descriptor = FetchDescriptor<ChecklistItemResult>(
            sortBy: [SortDescriptor(\ChecklistItemResult.orderIndex)]
        )
        descriptor.fetchLimit = PerformanceConfig.checklistItemResultFetchLimit
        let batch = (try? context.fetch(descriptor)) ?? []
        return batch.filter { runIds.contains($0.checklistRunId) }
    }
}
