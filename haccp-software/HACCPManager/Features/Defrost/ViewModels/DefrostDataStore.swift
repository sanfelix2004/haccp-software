//
//  DefrostDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class DefrostDataStore: ObservableObject {
    @Published private(set) var records: [DefrostRecord] = []
    @Published private(set) var criticalities: [DefrostCriticality] = []
    @Published private(set) var traceabilityRecords: [TraceabilityRecord] = []
    @Published private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?
    private var reloadPolicy = DataStoreReloadPolicy()

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(
            restaurantId: restaurantId,
            hasData: !records.isEmpty,
            force: force
        ) else { return }

        isLoading = true
        loadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            let data = DefrostDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            records = data.records
            criticalities = data.criticalities
            traceabilityRecords = data.traceabilityRecords
            DefrostService().refreshDelayedStatuses(
                records: records,
                settings: SettingsStorageService.shared.haccp
            )
            isLoading = false
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func defrosts(forTraceabilityId id: UUID) -> [DefrostRecord] {
        records.filter { $0.traceabilityItemId == id }
    }

    func clear() {
        reloadPolicy.invalidate()
        records = []
        criticalities = []
        traceabilityRecords = []
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
