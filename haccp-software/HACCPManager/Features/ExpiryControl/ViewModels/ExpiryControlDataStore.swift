//
//  ExpiryControlDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ExpiryControlDataStore: ObservableObject {
    @Published private(set) var records: [TraceabilityRecord] = []
    @Published private(set) var lottoFotos: [LottoFoto] = []
    @Published private(set) var productImages: [ProductImage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadGeneration = UUID()

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
            let data = ExpiryControlDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            records = data.records
            lottoFotos = data.lottoFotos
            productImages = data.productImages
            isLoading = false
            loadGeneration = UUID()
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        records = []
        lottoFotos = []
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
