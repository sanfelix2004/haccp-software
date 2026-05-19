//
//  HistoryDataFetcher.swift
//  Fetch mirati con limite — evita caricare l'intero database in RAM.
//

import Foundation
import SwiftData

struct HistoryFetchedData {
    var temperatureRecords: [TemperatureRecord] = []
    var fridgeRecords: [FridgeCheckRecord] = []
    var checklistRuns: [ChecklistRun] = []
    var checklistItemResults: [ChecklistItemResult] = []
    var checklistAuditLogs: [ChecklistAuditLog] = []
    var cleaningRecords: [CleaningRecord] = []
    var defrostRecords: [DefrostRecord] = []
    var blastRecords: [BlastChillingRecord] = []
    var labelRecords: [ProductionLabelRecord] = []
    var goodsRecords: [GoodsReceipt] = []
    var traceabilityRecords: [TraceabilityRecord] = []
    var traceabilityLogs: [TraceabilityLog] = []
    var scheduledTasks: [ScheduledTask] = []
    var oilRecords: [OilControlRecord] = []
}

@MainActor
enum HistoryDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> HistoryFetchedData {
        let limit = PerformanceConfig.historyFetchLimitPerType
        let rid = restaurantId

        var data = HistoryFetchedData()
        data.temperatureRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\TemperatureRecord.measuredAt, order: .reverse))
        data.fridgeRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\FridgeCheckRecord.createdAt, order: .reverse))
        data.checklistRuns = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\ChecklistRun.startedAt, order: .reverse))
        data.checklistItemResults = fetchChecklistItemResults(context, runIds: Set(data.checklistRuns.map(\.id)), limit: limit * 2)
        data.checklistAuditLogs = fetchLimited(context, restaurantId: rid, limit: min(limit, 200), sort: SortDescriptor(\ChecklistAuditLog.timestamp, order: .reverse))
        data.cleaningRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\CleaningRecord.createdAt, order: .reverse))
        data.defrostRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\DefrostRecord.startAt, order: .reverse))
        data.blastRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\BlastChillingRecord.startedAt, order: .reverse))
        data.labelRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\ProductionLabelRecord.createdAt, order: .reverse))
        data.goodsRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\GoodsReceipt.receivedAt, order: .reverse))
        data.traceabilityRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\TraceabilityRecord.createdAt, order: .reverse))
        data.traceabilityLogs = fetchTraceabilityLogs(
            context,
            recordIds: Set(data.traceabilityRecords.map(\.id)),
            limit: limit
        )
        data.scheduledTasks = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\ScheduledTask.createdAt, order: .reverse))
        data.oilRecords = fetchLimited(context, restaurantId: rid, limit: limit, sort: SortDescriptor(\OilControlRecord.checkedAt, order: .reverse))
        return data
    }

    private static func fetchLimited<T: PersistentModel>(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int,
        sort: SortDescriptor<T>
    ) -> [T] where T: RestaurantScoped {
        var descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.restaurantId == restaurantId },
            sortBy: [sort]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchTraceabilityLogs(
        _ context: ModelContext,
        recordIds: Set<UUID>,
        limit: Int
    ) -> [TraceabilityLog] {
        guard !recordIds.isEmpty else { return [] }
        var descriptor = FetchDescriptor<TraceabilityLog>(
            sortBy: [SortDescriptor(\TraceabilityLog.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let batch = (try? context.fetch(descriptor)) ?? []
        return batch.filter { recordIds.contains($0.receivedItemId) }
    }

    private static func fetchChecklistItemResults(
        _ context: ModelContext,
        runIds: Set<UUID>,
        limit: Int
    ) -> [ChecklistItemResult] {
        guard !runIds.isEmpty else { return [] }
        var descriptor = FetchDescriptor<ChecklistItemResult>(
            sortBy: [SortDescriptor(\ChecklistItemResult.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let batch = (try? context.fetch(descriptor)) ?? []
        return batch.filter { runIds.contains($0.checklistRunId) }
    }
}

/// Modelli con `restaurantId` per fetch mirati.
protocol RestaurantScoped {
    var restaurantId: UUID { get }
}

extension TemperatureRecord: RestaurantScoped {}
extension FridgeCheckRecord: RestaurantScoped {}
extension ChecklistRun: RestaurantScoped {}
extension ChecklistAuditLog: RestaurantScoped {}
extension CleaningRecord: RestaurantScoped {}
extension DefrostRecord: RestaurantScoped {}
extension BlastChillingRecord: RestaurantScoped {}
extension ProductionLabelRecord: RestaurantScoped {}
extension GoodsReceipt: RestaurantScoped {}
extension TraceabilityRecord: RestaurantScoped {}
extension ScheduledTask: RestaurantScoped {}
extension OilControlRecord: RestaurantScoped {}
extension DocumentFolder: RestaurantScoped {}
