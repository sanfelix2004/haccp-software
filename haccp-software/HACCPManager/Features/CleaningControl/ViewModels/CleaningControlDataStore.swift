//
//  CleaningControlDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class CleaningControlDataStore: ObservableObject {
    @Published private(set) var areas: [CleaningArea] = []
    @Published private(set) var tasks: [CleaningTask] = []
    @Published private(set) var records: [CleaningRecord] = []
    @Published private(set) var criticalities: [CleaningCriticality] = []
    @Published private(set) var checklistTemplates: [ChecklistTemplate] = []
    @Published private(set) var checklistRuns: [ChecklistRun] = []
    @Published private(set) var checklistItemResults: [ChecklistItemResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshingSupplementary = false
    @Published private(set) var dataRevision = UUID()

    private var loadTask: Task<Void, Never>?
    private var reloadPolicy = DataStoreReloadPolicy()

    private var hasOperationalData: Bool {
        !tasks.isEmpty || !checklistTemplates.isEmpty || !areas.isEmpty
    }

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(
            restaurantId: restaurantId,
            hasData: hasOperationalData,
            force: force
        ) else { return }

        let showBlockingSpinner = !hasOperationalData
        if showBlockingSpinner {
            isLoading = true
        } else {
            isRefreshingSupplementary = true
        }

        loadTask = performLoad(
            context: context,
            restaurantId: restaurantId,
            showBlockingSpinner: showBlockingSpinner
        )
    }

    func reloadAndWait(context: ModelContext, restaurantId: UUID?, force: Bool = false) async {
        reload(context: context, restaurantId: restaurantId, force: force)
        await loadTask?.value
    }

    private func performLoad(
        context: ModelContext,
        restaurantId: UUID,
        showBlockingSpinner: Bool
    ) -> Task<Void, Never> {
        Task(priority: .utility) { @MainActor in
            defer {
                if !Task.isCancelled {
                    isLoading = false
                    isRefreshingSupplementary = false
                }
            }
            await MainThreadYield.afterNavigation()
            guard !Task.isCancelled else { return }

            // Fase 1: dati operativi — UI reattiva subito.
            let operational = await CleaningControlDataFetcher.fetchOperationalAsync(
                context: context,
                restaurantId: restaurantId
            )
            guard !Task.isCancelled else { return }

            areas = operational.areas
            tasks = operational.tasks
            checklistTemplates = operational.checklistTemplates
            checklistRuns = operational.checklistRuns
            dataRevision = UUID()

            if showBlockingSpinner {
                isLoading = false
            }

            // Fase 2: storico e dettagli — in background.
            let templateIds = Set(operational.checklistTemplates.map(\.id))
            let runIds = Set(operational.checklistRuns.map(\.id))
            let supplementary = await CleaningControlDataFetcher.fetchSupplementaryAsync(
                context: context,
                restaurantId: restaurantId,
                templateIds: templateIds,
                runIds: runIds
            )
            guard !Task.isCancelled else { return }

            records = supplementary.records
            criticalities = supplementary.criticalities
            checklistItemResults = supplementary.itemResults
            dataRevision = UUID()
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        areas = []
        tasks = []
        records = []
        criticalities = []
        checklistTemplates = []
        checklistRuns = []
        checklistItemResults = []
        isLoading = false
        isRefreshingSupplementary = false
        dataRevision = UUID()
    }

    func cancelPendingLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    deinit {
        loadTask?.cancel()
    }
}
