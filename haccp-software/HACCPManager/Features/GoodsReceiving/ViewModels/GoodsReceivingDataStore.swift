//
//  GoodsReceivingDataStore.swift
//

import Foundation
import SwiftData
import Combine
import SwiftUI

// MARK: - GoodsReceivingDataStore
// Sorgente di verità per i dati operativi della Ricezione Merci.
// Separata dal ViewModel (che gestisce solo lo stato UI/UX) per rispettare
// la separazione delle responsabilità.

@MainActor
final class GoodsReceivingDataStore: ObservableObject {

    // MARK: - Published Data (read-only dall'esterno)

    @Published private(set) var records: [GoodsReceipt] = []
    @Published private(set) var suppliers: [Supplier] = []
    @Published private(set) var templates: [ProductTemplate] = []
    @Published private(set) var productImages: [ProductImage] = []
    @Published private(set) var isLoading = false

    // MARK: - Private

    private var loadTask: Task<Void, Never>?
    private var reloadPolicy = DataStoreReloadPolicy()

    // MARK: - Optimistic Updates

    /// Inserisce immediatamente il fornitore nella lista in memoria senza aspettare il reload.
    /// Usato per aggiornamento ottimistico dopo creazione di un nuovo fornitore:
    /// l'utente vede il nuovo fornitore istantaneamente, senza alcun delay percettibile.
    func appendSupplier(_ supplier: Supplier) {
        guard !suppliers.contains(where: { $0.id == supplier.id }) else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            suppliers.insert(supplier, at: 0)
        }
    }

    // MARK: - Reload

    /// Ricarica i dati bypassando la policy di debounce.
    /// Usare dopo operazioni che modificano i dati per garantire coerenza.
    func forceReload(context: ModelContext, restaurantId: UUID?) {
        reload(context: context, restaurantId: restaurantId, force: true)
    }

    func reload(context: ModelContext, restaurantId: UUID?, force: Bool = false) {
        loadTask?.cancel()
        guard let restaurantId else {
            clear()
            return
        }
        guard reloadPolicy.shouldReload(
            restaurantId: restaurantId,
            hasData: !records.isEmpty || !templates.isEmpty,
            force: force
        ) else { return }

        isLoading = true
        loadTask = Task { @MainActor in
            // Yield per non bloccare il thread principale durante il fetch iniziale.
            await Task.yield()
            guard !Task.isCancelled else { return }
            let data = GoodsReceivingDataFetcher.fetch(context: context, restaurantId: restaurantId)
            guard !Task.isCancelled else { return }
            records = data.records
            suppliers = data.suppliers
            templates = data.templates
            productImages = data.productImages
            isLoading = false
            reloadPolicy.markLoaded(restaurantId: restaurantId)
        }
    }

    // MARK: - Clear

    func clear() {
        reloadPolicy.invalidate()
        records = []
        suppliers = []
        templates = []
        productImages = []
        isLoading = false
        loadTask?.cancel()
        loadTask = nil
    }

    func cancelPendingLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    deinit {
        loadTask?.cancel()
    }
}
