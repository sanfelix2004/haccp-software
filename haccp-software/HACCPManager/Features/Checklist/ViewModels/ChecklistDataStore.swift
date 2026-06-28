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

    func reload(context: ModelContext, restaurantId: UUID?) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }

        let token = MainActorDataLoad.begin(generation: &reloadGeneration)
        isLoading = true
        loadTask = Task { @MainActor in
            defer {
                if MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration) {
                    isLoading = false
                }
            }
            await Task.yield()
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            let data = ChecklistDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            templates = data.templates
            runs = data.runs
            itemResults = data.itemResults
            alerts = data.alerts
            cleaningCriticalities = data.cleaningCriticalities
        }
    }

    func clear() {
        templates = []
        runs = []
        itemResults = []
        alerts = []
        cleaningCriticalities = []
        isLoading = false
    }

    deinit {
        loadTask?.cancel()
    }
}
