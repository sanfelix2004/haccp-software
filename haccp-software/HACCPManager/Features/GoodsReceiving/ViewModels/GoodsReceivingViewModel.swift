import Foundation
import Combine
import SwiftUI

// MARK: - GoodsReceivingViewModel
// Gestisce lo stato UI volatile della schermata Ricezione Merci.
// NON conosce il database — opera solo su valori derivati e memoria utente.

@MainActor
final class GoodsReceivingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedSupplier: Supplier?
    @Published var selectedCategory: GoodsCategory = .all
    @Published var selectedProduct: ProductTemplate?
    @Published var errorMessage: String?

    // MARK: - User Memory (persisted across sessions)

    @Published private(set) var recentProductIds: [UUID] = []
    @Published private(set) var lastSupplierId: UUID?

    // MARK: - Computed Helpers

    /// `true` solo se fornitore E prodotto sono entrambi selezionati.
    var canConfirmIntake: Bool {
        selectedSupplier != nil && selectedProduct != nil
    }

    // MARK: - Memory Persistence
    // Chiave UserDefaults basata su restaurantId per isolare i dati per ristorante.

    func loadMemory(restaurantId: UUID) {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: supplierKey(restaurantId)),
           let id = UUID(uuidString: raw) {
            lastSupplierId = id
        }
        if let recent = defaults.array(forKey: recentKey(restaurantId)) as? [String] {
            recentProductIds = recent.compactMap(UUID.init(uuidString:))
        }
    }

    func persistMemory(restaurantId: UUID) {
        let defaults = UserDefaults.standard
        // Persiste nil esplicitamente per pulire la chiave quando non c'è fornitore selezionato.
        defaults.set(selectedSupplier?.id.uuidString, forKey: supplierKey(restaurantId))
        defaults.set(recentProductIds.map(\.uuidString), forKey: recentKey(restaurantId))
    }

    // MARK: - Actions

    /// Seleziona un template di prodotto e lo sposta in cima ai recenti.
    /// Previene duplicati: rimuove l'occorrenza precedente prima di reinserire in cima.
    func selectProductTemplate(_ product: ProductTemplate) {
        selectedProduct = product
        recentProductIds.removeAll { $0 == product.id }
        recentProductIds.insert(product.id, at: 0)
        recentProductIds = Array(recentProductIds.prefix(8))
    }

    /// Resetta lo stato post-salvataggio per la prossima ricezione.
    /// Mantiene il fornitore selezionato (UX fluida: spesso si riceve dallo stesso fornitore).
    func resetForNext() {
        selectedProduct = nil
    }

    // MARK: - Private Helpers

    private func supplierKey(_ id: UUID) -> String { "last_supplier_\(id.uuidString)" }
    private func recentKey(_ id: UUID)   -> String { "recent_products_\(id.uuidString)" }
}
