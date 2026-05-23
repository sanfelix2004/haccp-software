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

    func reload(context: ModelContext, restaurantId: UUID?) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        isLoading = true
        loadTask = Task {
            await Task.yield()
            let data = DefrostDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            records = data.records
            criticalities = data.criticalities
            traceabilityRecords = data.traceabilityRecords
            DefrostService().refreshDelayedStatuses(records: records)
            isLoading = false
        }
    }

    func defrosts(forTraceabilityId id: UUID) -> [DefrostRecord] {
        records.filter { $0.traceabilityItemId == id }
    }

    func clear() {
        records = []
        criticalities = []
        traceabilityRecords = []
        isLoading = false
    }

    deinit {
        loadTask?.cancel()
    }
}
