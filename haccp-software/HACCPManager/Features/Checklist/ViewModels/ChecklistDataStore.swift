//
//  ChecklistDataStore.swift
//  Stato checklist caricato on-demand — sostituisce @Query globali.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ChecklistDataStore: ObservableObject {
    @Published private(set) var templates: [ChecklistTemplate] = []
    @Published private(set) var runs: [ChecklistRun] = []
    @Published private(set) var itemResults: [ChecklistItemResult] = []
    @Published private(set) var alerts: [ChecklistAlert] = []
    @Published private(set) var cleaningCriticalities: [CleaningCriticality] = []
    @Published private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?
    private var reloadGeneration = 0
    private var reloadPolicy = DataStoreReloadPolicy()

    private var hasData: Bool {
        !templates.isEmpty || !runs.isEmpty
    }

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(
            restaurantId: restaurantId,
            hasData: hasData,
            force: force
        ) else { return }

        let showBlockingSpinner = !hasData
        if showBlockingSpinner {
            isLoading = true
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
        let token = MainActorDataLoad.begin(generation: &reloadGeneration)
        return Task(priority: .utility) { @MainActor in
            defer {
                if MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration) {
                    isLoading = false
                }
            }
            await MainThreadYield.afterNavigation()
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            let data = await ChecklistDataFetcher.fetchAsync(
                context: context,
                restaurantId: restaurantId
            )
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            templates = data.templates
            runs = data.runs
            itemResults = data.itemResults
            alerts = data.alerts
            cleaningCriticalities = data.cleaningCriticalities
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        templates = []
        runs = []
        itemResults = []
        alerts = []
        cleaningCriticalities = []
        isLoading = false
    }

    func cancelPendingLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    deinit {
        loadTask?.cancel()
    }
}
