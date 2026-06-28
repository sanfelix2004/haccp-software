//
//  DashboardMetricsFetcher.swift
//  Conteggi leggeri per badge dashboard (no @Query globali).
//

import Foundation
import SwiftData

struct DashboardMetrics: Equatable {
    var activeAlerts: Int = 0
    var temperatureAlerts: Int = 0
    var openTasks: Int = 0
    var todayRecords: Int = 0
    var traceabilityCount: Int = 0
    var blastCount: Int = 0
    var incompleteCleaning: Int = 0
    var documentItems: Int = 0

    static let empty = DashboardMetrics()
}

@MainActor
enum DashboardMetricsFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> DashboardMetrics {
        let limit = PerformanceConfig.dashboardSampleLimit
        var metrics = DashboardMetrics()

        metrics.activeAlerts = countActiveAlerts(context, restaurantId: restaurantId, limit: limit)
        metrics.temperatureAlerts = countTemperatureAlerts(context, restaurantId: restaurantId, limit: limit)
        metrics.openTasks = count(
            context,
            restaurantId: restaurantId,
            limit: limit,
            type: ChecklistRun.self
        ) { runs in
            runs.filter {
                !$0.isArchived && ($0.status == .notStarted || $0.status == .inProgress || $0.status == .overdue)
            }.count
        }
        metrics.traceabilityCount = countActive(
            context,
            restaurantId: restaurantId,
            limit: limit,
            type: TraceabilityRecord.self
        ) { $0.count }
        metrics.blastCount = countActive(
            context,
            restaurantId: restaurantId,
            limit: limit,
            type: BlastChillingRecord.self
        ) { $0.count }
        metrics.incompleteCleaning = countActive(
            context,
            restaurantId: restaurantId,
            limit: limit,
            type: CleaningRecord.self
        ) { rows in rows.filter { !$0.completed }.count }
        metrics.documentItems = {
            let rid = restaurantId
            var docDesc = FetchDescriptor<DocumentItem>(
                predicate: #Predicate { $0.restaurantId == rid }
            )
            docDesc.fetchLimit = limit
            return (try? context.fetch(docDesc))?.count ?? 0
        }()
        metrics.todayRecords = countTodayRecords(context, restaurantId: restaurantId, limit: limit)

        return metrics
    }

    private static func countTodayRecords(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int
    ) -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let rid = restaurantId

        var goodsDesc = FetchDescriptor<GoodsReceipt>(
            predicate: #Predicate { $0.restaurantId == rid && $0.createdAt >= start }
        )
        goodsDesc.fetchLimit = limit
        let goods = (try? context.fetch(goodsDesc))?.count ?? 0

        var tempDesc = FetchDescriptor<TemperatureRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.measuredAt >= start }
        )
        tempDesc.fetchLimit = limit
        let temps = (try? context.fetch(tempDesc))?.count ?? 0

        var blastDesc = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && $0.createdAt >= start }
        )
        blastDesc.fetchLimit = limit
        let blast = (try? context.fetch(blastDesc))?.count ?? 0

        var checklistDesc = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { $0.restaurantId == rid && $0.startedAt >= start }
        )
        checklistDesc.fetchLimit = limit
        let checklist = (try? context.fetch(checklistDesc))?.count ?? 0

        return goods + temps + blast + checklist
    }

    private static func countActiveAlerts(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int
    ) -> Int {
        let rid = restaurantId
        var tempDesc = FetchDescriptor<TemperatureAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive }
        )
        tempDesc.fetchLimit = limit
        let temp = (try? context.fetch(tempDesc)) ?? []

        var oilDesc = FetchDescriptor<OilControlAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive }
        )
        oilDesc.fetchLimit = limit
        let oil = (try? context.fetch(oilDesc)) ?? []

        var cleaningDesc = FetchDescriptor<CleaningCriticality>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isResolved }
        )
        cleaningDesc.fetchLimit = limit
        let cleaning = (try? context.fetch(cleaningDesc)) ?? []

        var defrostDesc = FetchDescriptor<DefrostCriticality>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isResolved }
        )
        defrostDesc.fetchLimit = limit
        let defrost = (try? context.fetch(defrostDesc)) ?? []

        var checklistDesc = FetchDescriptor<ChecklistAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive }
        )
        checklistDesc.fetchLimit = limit
        let checklist = (try? context.fetch(checklistDesc)) ?? []

        var traceDesc = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived }
        )
        traceDesc.fetchLimit = limit * 4
        let trace = (try? context.fetch(traceDesc)) ?? []

        var goodsDesc = FetchDescriptor<GoodsReceivingRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived }
        )
        goodsDesc.fetchLimit = limit * 2
        let goods = (try? context.fetch(goodsDesc)) ?? []

        var labelDesc = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived }
        )
        labelDesc.fetchLimit = limit * 2
        let labels = (try? context.fetch(labelDesc)) ?? []

        let soonThreshold = SettingsStorageService.shared.haccp.productExpiryThreshold
        return HACCPUnifiedAlertsBuilder.count(
            restaurantId: restaurantId,
            temperatureAlerts: temp,
            cleaningCriticalities: cleaning,
            defrostCriticalities: defrost,
            oilAlerts: oil,
            checklistAlerts: checklist,
            traceabilityRecords: trace,
            goodsReceipts: goods,
            productionLabels: labels,
            soonThresholdDays: soonThreshold
        )
    }

    private static func countTemperatureAlerts(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int
    ) -> Int {
        let rid = restaurantId
        var descriptor = FetchDescriptor<TemperatureAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive }
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor))?.count ?? 0
    }

    private static func count<T: PersistentModel>(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int,
        type: T.Type,
        reduce: ([T]) -> Int
    ) -> Int where T: RestaurantScoped {
        let rid = restaurantId
        var descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        descriptor.fetchLimit = limit
        let batch = (try? context.fetch(descriptor)) ?? []
        return reduce(batch)
    }

    private static func countActive<T: PersistentModel>(
        _ context: ModelContext,
        restaurantId: UUID,
        limit: Int,
        type: T.Type,
        reduce: ([T]) -> Int
    ) -> Int where T: ArchivableRecord {
        let rid = restaurantId
        var descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived }
        )
        descriptor.fetchLimit = limit
        let batch = (try? context.fetch(descriptor)) ?? []
        return reduce(batch)
    }
}
