//
//  GoodsReceivingDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class GoodsReceivingDataStore: ObservableObject {
    @Published private(set) var records: [GoodsReceipt] = []
    @Published private(set) var suppliers: [Supplier] = []
    @Published private(set) var templates: [ProductTemplate] = []
    @Published private(set) var productImages: [ProductImage] = []
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
            hasData: !records.isEmpty || !templates.isEmpty,
            force: force
        ) else { return }

        isLoading = true
        loadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            let data = GoodsReceivingDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            records = data.records
            suppliers = data.suppliers
            templates = data.templates
            productImages = data.productImages
            isLoading = false
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        records = []
        suppliers = []
        templates = []
        productImages = []
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
