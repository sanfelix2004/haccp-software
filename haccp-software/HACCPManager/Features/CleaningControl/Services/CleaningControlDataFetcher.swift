//
//  CleaningControlDataFetcher.swift
//

import Foundation
import SwiftData

struct CleaningControlFetchedData {
    var areas: [CleaningArea] = []
    var tasks: [CleaningTask] = []
    var records: [CleaningRecord] = []
    var criticalities: [CleaningCriticality] = []
    var checklistTemplates: [ChecklistTemplate] = []
    var checklistRuns: [ChecklistRun] = []
    var checklistItemResults: [ChecklistItemResult] = []
}

enum CleaningControlDataFetcher {

    private static func yieldBetweenFetches() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 8_000_000)
    }

    static func fetch(context: ModelContext, restaurantId: UUID) -> CleaningControlFetchedData {
        fetchSync(context: context, restaurantId: restaurantId)
    }

    /// Fase 1 — minimo per mostrare subito la dashboard (aree, task, run pulizia).
    static func fetchOperationalAsync(
        context: ModelContext,
        restaurantId: UUID
    ) async -> CleaningControlFetchedData {
        let rid = restaurantId
        var data = CleaningControlFetchedData()

        var areaDescriptor = FetchDescriptor<CleaningArea>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningArea.name)]
        )
        areaDescriptor.fetchLimit = 100
        data.areas = (try? context.fetch(areaDescriptor)) ?? []
        await yieldBetweenFetches()

        var taskDescriptor = FetchDescriptor<CleaningTask>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive },
            sortBy: [SortDescriptor(\CleaningTask.title)]
        )
        taskDescriptor.fetchLimit = 120
        data.tasks = (try? context.fetch(taskDescriptor)) ?? []
        await yieldBetweenFetches()

        var templateDescriptor = FetchDescriptor<ChecklistTemplate>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive },
            sortBy: [SortDescriptor(\ChecklistTemplate.title)]
        )
        templateDescriptor.fetchLimit = PerformanceConfig.checklistTemplateFetchLimit
        data.checklistTemplates = ((try? context.fetch(templateDescriptor)) ?? [])
            .filter(\.matchesCleaningModuleFilter)
        await yieldBetweenFetches()

        let templateIds = Set(data.checklistTemplates.map(\.id))
        guard !templateIds.isEmpty else { return data }

        var runDescriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\ChecklistRun.dueAt)]
        )
        runDescriptor.fetchLimit = PerformanceConfig.checklistRunFetchLimit
        data.checklistRuns = ((try? context.fetch(runDescriptor)) ?? [])
            .filter { templateIds.contains($0.templateId) }

        return data
    }

    /// Fase 2 — storico, criticità e risultati voci (differibile).
    static func fetchSupplementaryAsync(
        context: ModelContext,
        restaurantId: UUID,
        templateIds: Set<UUID>,
        runIds: Set<UUID>
    ) async -> (
        records: [CleaningRecord],
        criticalities: [CleaningCriticality],
        itemResults: [ChecklistItemResult]
    ) {
        let rid = restaurantId

        var recordDescriptor = FetchDescriptor<CleaningRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\CleaningRecord.updatedAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        let records = (try? context.fetch(recordDescriptor)) ?? []
        await yieldBetweenFetches()

        var criticalityDescriptor = FetchDescriptor<CleaningCriticality>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningCriticality.createdAt, order: .reverse)]
        )
        criticalityDescriptor.fetchLimit = PerformanceConfig.checklistCleaningCriticalityFetchLimit
        let criticalities = (try? context.fetch(criticalityDescriptor)) ?? []
        await yieldBetweenFetches()

        guard !runIds.isEmpty else {
            return (records, criticalities, [])
        }

        var resultDescriptor = FetchDescriptor<ChecklistItemResult>(
            sortBy: [SortDescriptor(\ChecklistItemResult.orderIndex)]
        )
        resultDescriptor.fetchLimit = min(PerformanceConfig.checklistItemResultFetchLimit, runIds.count * 8)
        let itemResults = ((try? context.fetch(resultDescriptor)) ?? [])
            .filter { runIds.contains($0.checklistRunId) }

        return (records, criticalities, itemResults)
    }

    static func fetchAsync(context: ModelContext, restaurantId: UUID) async -> CleaningControlFetchedData {
        var data = await fetchOperationalAsync(context: context, restaurantId: restaurantId)
        let templateIds = Set(data.checklistTemplates.map(\.id))
        let runIds = Set(data.checklistRuns.map(\.id))
        let supplementary = await fetchSupplementaryAsync(
            context: context,
            restaurantId: restaurantId,
            templateIds: templateIds,
            runIds: runIds
        )
        data.records = supplementary.records
        data.criticalities = supplementary.criticalities
        data.checklistItemResults = supplementary.itemResults
        return data
    }

    private static func fetchSync(context: ModelContext, restaurantId: UUID) -> CleaningControlFetchedData {
        let rid = restaurantId
        var data = CleaningControlFetchedData()

        var areaDescriptor = FetchDescriptor<CleaningArea>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningArea.name)]
        )
        areaDescriptor.fetchLimit = 100
        data.areas = (try? context.fetch(areaDescriptor)) ?? []

        var taskDescriptor = FetchDescriptor<CleaningTask>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningTask.title)]
        )
        taskDescriptor.fetchLimit = 300
        data.tasks = (try? context.fetch(taskDescriptor)) ?? []

        var recordDescriptor = FetchDescriptor<CleaningRecord>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\CleaningRecord.updatedAt, order: .reverse)]
        )
        recordDescriptor.fetchLimit = PerformanceConfig.analyticsSeriesFetchLimit
        data.records = (try? context.fetch(recordDescriptor)) ?? []

        var criticalityDescriptor = FetchDescriptor<CleaningCriticality>(
            predicate: #Predicate { $0.restaurantId == rid },
            sortBy: [SortDescriptor(\CleaningCriticality.createdAt, order: .reverse)]
        )
        criticalityDescriptor.fetchLimit = PerformanceConfig.checklistCleaningCriticalityFetchLimit
        data.criticalities = (try? context.fetch(criticalityDescriptor)) ?? []

        var templateDescriptor = FetchDescriptor<ChecklistTemplate>(
            predicate: #Predicate { $0.restaurantId == rid && $0.isActive },
            sortBy: [SortDescriptor(\ChecklistTemplate.title)]
        )
        templateDescriptor.fetchLimit = PerformanceConfig.checklistTemplateFetchLimit
        data.checklistTemplates = ((try? context.fetch(templateDescriptor)) ?? [])
            .filter(\.matchesCleaningModuleFilter)

        let templateIds = Set(data.checklistTemplates.map(\.id))
        guard !templateIds.isEmpty else { return data }

        var runDescriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\ChecklistRun.startedAt, order: .reverse)]
        )
        runDescriptor.fetchLimit = PerformanceConfig.checklistRunFetchLimit
        data.checklistRuns = ((try? context.fetch(runDescriptor)) ?? [])
            .filter { templateIds.contains($0.templateId) }

        let runIds = Set(data.checklistRuns.map(\.id))
        guard !runIds.isEmpty else { return data }

        var resultDescriptor = FetchDescriptor<ChecklistItemResult>(
            sortBy: [SortDescriptor(\ChecklistItemResult.orderIndex)]
        )
        resultDescriptor.fetchLimit = PerformanceConfig.checklistItemResultFetchLimit
        data.checklistItemResults = ((try? context.fetch(resultDescriptor)) ?? [])
            .filter { runIds.contains($0.checklistRunId) }

        return data
    }
}
