//
//  AlertsDataStore.swift
//

import Foundation
import SwiftData
import Combine

@MainActor
final class AlertsDataStore: ObservableObject {
    @Published private(set) var checklistAlerts: [ChecklistAlert] = []
    @Published private(set) var temperatureAlerts: [TemperatureAlert] = []
    @Published private(set) var cleaningCriticalities: [CleaningCriticality] = []
    @Published private(set) var oilAlerts: [OilControlAlert] = []
    @Published private(set) var defrostCriticalities: [DefrostCriticality] = []
    @Published private(set) var traceabilityRecords: [TraceabilityRecord] = []
    @Published private(set) var goodsReceipts: [GoodsReceivingRecord] = []
    @Published private(set) var productionLabels: [ProductionLabelRecord] = []
    @Published private(set) var isLoading = false

    private var loadTask: Task<Void, Never>?
    private var reloadPolicy = DataStoreReloadPolicy()

    var hasData: Bool {
        !checklistAlerts.isEmpty
            || !temperatureAlerts.isEmpty
            || !cleaningCriticalities.isEmpty
            || !oilAlerts.isEmpty
            || !defrostCriticalities.isEmpty
            || !traceabilityRecords.isEmpty
            || !goodsReceipts.isEmpty
            || !productionLabels.isEmpty
    }

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(restaurantId: restaurantId, hasData: hasData, force: force) else {
            return
        }

        isLoading = true
        loadTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            let data = AlertsDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            checklistAlerts = data.checklistAlerts
            temperatureAlerts = data.temperatureAlerts
            cleaningCriticalities = data.cleaningCriticalities
            oilAlerts = data.oilAlerts
            defrostCriticalities = data.defrostCriticalities
            traceabilityRecords = data.traceabilityRecords
            goodsReceipts = data.goodsReceipts
            productionLabels = data.productionLabels
            isLoading = false
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        checklistAlerts = []
        temperatureAlerts = []
        cleaningCriticalities = []
        oilAlerts = []
        defrostCriticalities = []
        traceabilityRecords = []
        goodsReceipts = []
        productionLabels = []
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
