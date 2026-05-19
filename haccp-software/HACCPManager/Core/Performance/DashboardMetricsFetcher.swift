//
//  DashboardMetricsFetcher.swift
//  Conteggi leggeri per badge dashboard (no @Query globali).
//

import Foundation
import SwiftData

struct DashboardMetrics: Equatable {
    var activeAlerts: Int = 0
    var openTasks: Int = 0
    var traceabilityCount: Int = 0
    var blastCount: Int = 0
    var incompleteCleaning: Int = 0
    var documentFolders: Int = 0

    static let empty = DashboardMetrics()
}

@MainActor
enum DashboardMetricsFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> DashboardMetrics {
        let limit = PerformanceConfig.dashboardSampleLimit
        var metrics = DashboardMetrics()

        metrics.activeAlerts = countActiveAlerts(context, restaurantId: restaurantId, limit: limit)
        metrics.openTasks = count(
            context,
            restaurantId: restaurantId,
            limit: limit,
            type: ScheduledTask.self
        ) { tasks in tasks.filter { !$0.isCompleted }.count }
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
        metrics.documentFolders = count(
            context,
            restaurantId: restaurantId,
            limit: limit,
            type: DocumentFolder.self
        ) { $0.count }

        return metrics
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
        let temp = (try? context.fetch(tempDesc))?.count ?? 0

        var oilDesc = FetchDescriptor<OilControlAlert>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive }
        )
        oilDesc.fetchLimit = limit
        let oil = (try? context.fetch(oilDesc))?.count ?? 0
        return temp + oil
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
