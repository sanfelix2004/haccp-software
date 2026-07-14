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
    @Published private(set) var batches: [ProduzioneBatch] = []
    @Published private(set) var ingredientiTracciati: [IngredienteTracciato] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadGeneration = UUID()

    private var loadTask: Task<Void, Never>?
    private var reloadGeneration = 0
    private var reloadPolicy = DataStoreReloadPolicy()

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(
            restaurantId: restaurantId,
            hasData: !records.isEmpty,
            force: force
        ) else { return }

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

            // Fetch pesante: cede il main thread tra le fasi di lettura SwiftData.
            let data = await TraceabilityDataFetcher.fetchAsync(
                context: context,
                restaurantId: restaurantId
            )
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
            batches = data.batches
            ingredientiTracciati = data.ingredientiTracciati
            loadGeneration = UUID()
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func clear() {
        reloadPolicy.invalidate()
        records = []
        productions = []
        links = []
        logs = []
        images = []
        defrostRecords = []
        lottoFotos = []
        lottoProductionLinks = []
        batches = []
        ingredientiTracciati = []
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
