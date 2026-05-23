//
//  TraceabilityDataStore.swift
//  Stato caricato on-demand — evita @Query globali sulla tracciabilità.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class TraceabilityDataStore: ObservableObject {
    @Published private(set) var records: [TraceabilityRecord] = []
    @Published private(set) var productions: [Production] = []
    @Published private(set) var links: [TraceabilityLink] = []
    @Published private(set) var logs: [TraceabilityLog] = []
    @Published private(set) var images: [ProductImage] = []
    @Published private(set) var goodsReceipts: [GoodsReceipt] = []
    @Published private(set) var defrostRecords: [DefrostRecord] = []
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
            let data = TraceabilityDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            records = data.records
            productions = data.productions
            links = data.links
            logs = data.logs
            images = data.images
            goodsReceipts = data.goodsReceipts
            defrostRecords = data.defrostRecords
            isLoading = false
        }
    }

    func clear() {
        records = []
        productions = []
        links = []
        logs = []
        images = []
        goodsReceipts = []
        defrostRecords = []
        isLoading = false
    }

    deinit {
        loadTask?.cancel()
    }
}
