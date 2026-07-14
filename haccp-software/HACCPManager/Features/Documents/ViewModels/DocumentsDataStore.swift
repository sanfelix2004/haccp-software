//
//  DocumentsDataStore.swift
//  Archivio documenti caricato on-demand — sostituisce @Query globali.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class DocumentsDataStore: ObservableObject {
    @Published private(set) var folders: [DocumentFolder] = []
    @Published private(set) var items: [DocumentItem] = []
    @Published private(set) var isLoading = false

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
            hasData: !folders.isEmpty || !items.isEmpty,
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

            let data = DocumentsDataFetcher.fetchArchive(context: context, restaurantId: restaurantId)
            guard MainActorDataLoad.isCurrent(generation: token, activeGeneration: reloadGeneration),
                  !Task.isCancelled else { return }

            folders = data.folders
            items = data.items
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    func reloadSynchronously(context: ModelContext, restaurantId: UUID) {
        loadTask?.cancel()
        reloadGeneration += 1
        let data = DocumentsDataFetcher.fetchArchive(context: context, restaurantId: restaurantId)
        folders = data.folders
        items = data.items
        isLoading = false
        reloadPolicy.markLoaded(restaurantId: restaurantId)
    }

    func clear() {
        reloadPolicy.invalidate()
        folders = []
        items = []
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
