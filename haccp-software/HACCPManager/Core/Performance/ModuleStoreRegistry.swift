//
//  ModuleStoreRegistry.swift
//  DataStore condivisi tra visite — sopravvivono al cambio modulo senza ZStack multiplo.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ModuleStoreRegistry: ObservableObject {
    static let shared = ModuleStoreRegistry()

    let traceability = TraceabilityDataStore()
    let checklist = ChecklistDataStore()
    let blastChilling = BlastChillingDataStore()
    let documents = DocumentsDataStore()
    let productionLabels = ProductionLabelsDataStore()
    let alerts = AlertsDataStore()
    let productionCatalog = ProductionCatalogDataStore()
    let incomingFoodCatalog = IncomingFoodCatalogDataStore()
    let defrost = DefrostDataStore()
    let oilControl = OilControlDataStore()
    let cleaningControl = CleaningControlDataStore()
    let analytics = AnalyticsDataStore()
    let goodsReceiving = GoodsReceivingDataStore()
    let expiryControl = ExpiryControlDataStore()
    let history = HistoryLoaderViewModel()

    private init() {}

    func cancelAllPendingLoads() {
        traceability.cancelPendingLoad()
        checklist.cancelPendingLoad()
        blastChilling.cancelPendingLoad()
        documents.cancelPendingLoad()
        productionLabels.cancelPendingLoad()
        alerts.cancelPendingLoad()
        productionCatalog.cancelPendingLoad()
        incomingFoodCatalog.cancelPendingLoad()
        defrost.cancelPendingLoad()
        oilControl.cancelPendingLoad()
        cleaningControl.cancelPendingLoad()
        analytics.cancelPendingLoad()
        goodsReceiving.cancelPendingLoad()
        expiryControl.cancelPendingLoad()
        history.cancelPendingLoad()
    }

    func clearForRestaurantChange(context: ModelContext) {
        traceability.clear()
        checklist.clear()
        blastChilling.clear()
        documents.clear()
        productionLabels.clear()
        alerts.clear()
        productionCatalog.clear()
        incomingFoodCatalog.clear()
        defrost.clear()
        oilControl.clear()
        cleaningControl.clear()
        analytics.clear()
        goodsReceiving.clear()
        expiryControl.clear()
        history.reload(context: context, restaurantId: nil)
    }
}
