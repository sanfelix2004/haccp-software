//
//  ProductionLabelsDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ProductionLabelsDataStore: ObservableObject {
    @Published private(set) var labels: [ProductionLabelRecord] = []
    @Published private(set) var traceabilityRecords: [TraceabilityRecord] = []
    @Published private(set) var goodsReceipts: [GoodsReceivingRecord] = []
    @Published private(set) var blastRecords: [BlastChillingRecord] = []
    @Published private(set) var defrostRecords: [DefrostRecord] = []
    @Published private(set) var productions: [Production] = []
    @Published private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?

    private var reloadPolicy = DataStoreReloadPolicy()

    func reload(context: ModelContext, restaurantId: UUID?, includeArchived: Bool = false, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(
            restaurantId: restaurantId,
            hasData: !labels.isEmpty,
            force: force
        ) else { return }

        isLoading = true
        loadTask = Task { @MainActor in
            await Task.yield()
            let data = ProductionLabelDataFetcher.fetch(
                context: context,
                restaurantId: restaurantId,
                includeArchived: includeArchived
            )
            guard !Task.isCancelled else { return }
            labels = data.labels
            traceabilityRecords = data.traceabilityRecords
            goodsReceipts = data.goodsReceipts
            blastRecords = data.blastRecords
            defrostRecords = data.defrostRecords
            productions = data.productions
            isLoading = false
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        labels = []
        traceabilityRecords = []
        goodsReceipts = []
        blastRecords = []
        defrostRecords = []
        productions = []
        isLoading = false
    }

    func mergeFetchedLabel(_ label: ProductionLabelRecord) {
        guard !labels.contains(where: { $0.id == label.id }) else { return }
        labels.insert(label, at: 0)
    }

    func cancelPendingLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    deinit {
        loadTask?.cancel()
    }
}
