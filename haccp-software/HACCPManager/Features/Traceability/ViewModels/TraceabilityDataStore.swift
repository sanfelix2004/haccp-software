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
    @Published private(set) var defrostRecords: [DefrostRecord] = []
    @Published private(set) var lottoFotos: [LottoFoto] = []
    @Published private(set) var lottoProductionLinks: [LottoFotoProductionLink] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadGeneration = UUID()

    private var loadTask: Task<Void, Never>?
    private var reloadGeneration = 0

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

            let data = TraceabilityDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            records = data.records
            productions = data.productions
            links = data.links
            logs = data.logs
            images = data.images
            defrostRecords = data.defrostRecords
            lottoFotos = data.lottoFotos
            lottoProductionLinks = data.lottoProductionLinks
            loadGeneration = UUID()
        }
    }

    func clear() {
        records = []
        productions = []
        links = []
        logs = []
        images = []
        defrostRecords = []
        lottoFotos = []
        lottoProductionLinks = []
        isLoading = false
    }

    deinit {
        loadTask?.cancel()
    }
}
