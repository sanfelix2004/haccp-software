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

    func reload(context: ModelContext, restaurantId: UUID?, includeArchived: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        isLoading = true
        loadTask = Task {
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
        }
    }

    func clear() {
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

    deinit {
        loadTask?.cancel()
    }
}
