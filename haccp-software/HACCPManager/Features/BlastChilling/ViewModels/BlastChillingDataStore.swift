//
//  BlastChillingDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class BlastChillingDataStore: ObservableObject {
    @Published private(set) var records: [BlastChillingRecord] = []
    @Published private(set) var productionLabels: [ProductionLabelRecord] = []
    @Published private(set) var categories: [ProductionCategory] = []
    @Published private(set) var productions: [Production] = []
    @Published private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?
    private var reloadPolicy = DataStoreReloadPolicy()

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(restaurantId: restaurantId, hasData: !records.isEmpty, force: force) else {
            return
        }

        isLoading = true
        loadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            let data = BlastChillingDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            records = data.records
            productionLabels = data.productionLabels
            categories = data.categories
            productions = data.productions
            isLoading = false
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        records = []
        productionLabels = []
        categories = []
        productions = []
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
