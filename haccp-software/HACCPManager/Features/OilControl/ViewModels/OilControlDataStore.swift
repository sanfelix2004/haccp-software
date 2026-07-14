//
//  OilControlDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class OilControlDataStore: ObservableObject {
    @Published private(set) var points: [OilPoint] = []
    @Published private(set) var records: [OilControlRecord] = []
    @Published private(set) var alerts: [OilControlAlert] = []
    @Published private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?
    private var reloadPolicy = DataStoreReloadPolicy()

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(restaurantId: restaurantId, hasData: !points.isEmpty || !records.isEmpty, force: force) else {
            return
        }

        isLoading = true
        loadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            let data = OilControlDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            points = data.points
            records = data.records
            alerts = data.alerts
            isLoading = false
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        points = []
        records = []
        alerts = []
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
