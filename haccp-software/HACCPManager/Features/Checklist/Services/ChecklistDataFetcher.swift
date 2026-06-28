//
//  ChecklistDataFetcher.swift
//  Fetch mirati per ristorante — evita @Query globali in ChecklistView.
//

import Foundation
import SwiftData

struct ChecklistFetchedData {
    var templates: [ChecklistTemplate] = []
    var runs: [ChecklistRun] = []
    var itemResults: [ChecklistItemResult] = []
    var alerts: [ChecklistAlert] = []
    var cleaningCriticalities: [CleaningCriticality] = []
}

enum ChecklistDataFetcher {

    static func fetch(context: ModelContext, restaurantId: UUID) -> ChecklistFetchedData {
        let rid = restaurantId
        var data = ChecklistFetchedData()

        var templateDescriptor = FetchDescriptor<ChecklistTemplate>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ChecklistTemplate.title)]
        )
        templateDescriptor.fetchLimit = PerformanceConfig.checklistTemplateFetchLimit
        data.templates = (try? context.fetch(templateDescriptor)) ?? []

        var runDescriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\ChecklistRun.startedAt, order: .reverse)]
        )
        runDescriptor.fetchLimit = PerformanceConfig.checklistRunFetchLimit
        data.runs = (try? context.fetch(runDescriptor)) ?? []

        let runIds = Set(data.runs.map(\.id))
        data.itemResults = fetchItemResults(context, runIds: runIds)

        var alertDescriptor = FetchDescriptor<ChecklistAlert>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\ChecklistAlert.createdAt, order: .reverse)]
        )
        alertDescriptor.fetchLimit = PerformanceConfig.checklistAlertFetchLimit
        data.alerts = (try? context.fetch(alertDescriptor)) ?? []

        var criticalityDescriptor = FetchDescriptor<CleaningCriticality>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningCriticality.createdAt, order: .reverse)]
        )
        criticalityDescriptor.fetchLimit = PerformanceConfig.checklistCleaningCriticalityFetchLimit
        data.cleaningCriticalities = (try? context.fetch(criticalityDescriptor)) ?? []

        return data
    }

    private static func fetchItemResults(
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
