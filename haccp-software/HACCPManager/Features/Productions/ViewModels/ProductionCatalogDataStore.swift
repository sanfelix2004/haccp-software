//
//  ProductionCatalogDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ProductionCatalogDataStore: ObservableObject {
    @Published private(set) var categories: [ProductionCategory] = []
    @Published private(set) var productions: [Production] = []
    @Published private(set) var isLoading = false
    @Published private(set) var dataRevision = UUID()

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
            hasData: !categories.isEmpty || !productions.isEmpty,
            force: force
        ) else { return }

        let showBlockingSpinner = categories.isEmpty && productions.isEmpty
        if showBlockingSpinner {
            isLoading = true
        }

        loadTask = Task(priority: .utility) { @MainActor in
            await MainThreadYield.betweenFetchPhases()
            guard !Task.isCancelled else { return }
            let data = await ProductionCatalogDataFetcher.fetchAsync(
                context: context,
                restaurantId: restaurantId
            )
            guard !Task.isCancelled else { return }
            categories = data.categories
            productions = data.productions
            isLoading = false
            dataRevision = UUID()
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        categories = []
        productions = []
        isLoading = false
        dataRevision = UUID()
    }

    func cancelPendingLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    deinit {
        loadTask?.cancel()
    }
}
