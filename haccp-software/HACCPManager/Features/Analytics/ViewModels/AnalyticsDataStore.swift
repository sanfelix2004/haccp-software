//
//  AnalyticsDataStore.swift
//  Campioni grafici caricati on-demand — sostituisce 13 @Query globali.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class AnalyticsDataStore: ObservableObject {
    @Published private(set) var checklistRuns: [ChecklistRun] = []
    @Published private(set) var checklistResults: [ChecklistItemResult] = []
    @Published private(set) var checklistAlerts: [ChecklistAlert] = []
    @Published private(set) var temperatureRecords: [TemperatureRecord] = []
    @Published private(set) var temperatureDevices: [TemperatureDevice] = []
    @Published private(set) var cleaningRecords: [CleaningRecord] = []
    @Published private(set) var cleaningCriticalities: [CleaningCriticality] = []
    @Published private(set) var blastRecords: [BlastChillingRecord] = []
    @Published private(set) var defrostRecords: [DefrostRecord] = []
    @Published private(set) var oilRecords: [OilControlRecord] = []
    @Published private(set) var goodsRecords: [GoodsReceivingRecord] = []
    @Published private(set) var traceabilityRecords: [TraceabilityRecord] = []
    @Published private(set) var labelRecords: [ProductionLabelRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadGeneration = UUID()

    private var loadTask: Task<Void, Never>?
    private var reloadGeneration = 0

    var isEmpty: Bool {
        checklistRuns.isEmpty
            && temperatureRecords.isEmpty
            && cleaningRecords.isEmpty
            && blastRecords.isEmpty
            && defrostRecords.isEmpty
            && oilRecords.isEmpty
            && goodsRecords.isEmpty
            && traceabilityRecords.isEmpty
            && labelRecords.isEmpty
    }

    func reload(context: ModelContext, restaurantId: UUID?) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }

        let token = MainActorDataLoad.begin(generation: &reloadGeneration)
        isLoading = true
        loadTask = Task { @MainActor in
            defer {
                if MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration) {
                    isLoading = false
                }
            }
            await Task.yield()
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            let data = AnalyticsDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            checklistRuns = data.checklistRuns
            checklistResults = data.checklistResults
            checklistAlerts = data.checklistAlerts
            temperatureRecords = data.temperatureRecords
            temperatureDevices = data.temperatureDevices
            cleaningRecords = data.cleaningRecords
            cleaningCriticalities = data.cleaningCriticalities
            blastRecords = data.blastRecords
            defrostRecords = data.defrostRecords
            oilRecords = data.oilRecords
            goodsRecords = data.goodsRecords
            traceabilityRecords = data.traceabilityRecords
            labelRecords = data.labelRecords
            loadGeneration = UUID()
        }
    }

    func clear() {
        checklistRuns = []
        checklistResults = []
        checklistAlerts = []
        temperatureRecords = []
        temperatureDevices = []
        cleaningRecords = []
        cleaningCriticalities = []
        blastRecords = []
        defrostRecords = []
        oilRecords = []
        goodsRecords = []
        traceabilityRecords = []
        labelRecords = []
        isLoading = false
    }

    deinit {
        loadTask?.cancel()
    }
}
