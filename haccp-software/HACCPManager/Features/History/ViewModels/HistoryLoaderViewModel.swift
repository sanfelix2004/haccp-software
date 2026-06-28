//
//  HistoryLoaderViewModel.swift
//  Caricamento storico asincrono con fetch limitati.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class HistoryLoaderViewModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadToken = UUID()

    private let service = HistoryService()
    private var loadTask: Task<Void, Never>?
    private var reloadGeneration = 0

    func reload(context: ModelContext, restaurantId: UUID?) {
        loadTask?.cancel()
        guard let restaurantId else {
            entries = []
            isLoading = false
            return
        }

        let token = MainActorDataLoad.begin(generation: &reloadGeneration)
        isLoading = true
        let publishedToken = UUID()
        loadToken = publishedToken

        loadTask = Task { @MainActor in
            defer {
                if MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration) {
                    isLoading = false
                }
            }
            await Task.yield()
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            let data = HistoryDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            let built = service.buildEntries(
                restaurantId: restaurantId,
                temperatureRecords: data.temperatureRecords,
                fridgeRecords: data.fridgeRecords,
                checklistRuns: data.checklistRuns,
                checklistItemResults: data.checklistItemResults,
                cleaningRecords: data.cleaningRecords,
                defrostRecords: data.defrostRecords,
                blastRecords: data.blastRecords,
                labelRecords: data.labelRecords,
                goodsRecords: data.goodsRecords,
                traceabilityRecords: data.traceabilityRecords,
                traceabilityLinks: data.traceabilityLinks,
                traceabilityLogs: data.traceabilityLogs,
                lottoProductionLinks: data.lottoProductionLinks,
                lottoFotos: data.lottoFotos,
                productions: data.productions,
                oilRecords: data.oilRecords
            )

            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled,
                  loadToken == publishedToken else { return }
            entries = built
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
