import Foundation
import Combine

@MainActor
final class GoodsReceivingViewModel: ObservableObject {
    @Published var selectedSupplier: Supplier?
    @Published var selectedCategory: GoodsCategory = .all
    @Published var selectedProduct: ProductTemplate?
    @Published var errorMessage: String?
    @Published var showControlSheet = false

    @Published var recentProductIds: [UUID] = []
    @Published var lastSupplierId: UUID?

    let service = GoodsReceivingService()

    func loadMemory(restaurantId: UUID) {
        let defaults = UserDefaults.standard
        if let supplierRaw = defaults.string(forKey: "last_supplier_\(restaurantId)"),
           let supplierId = UUID(uuidString: supplierRaw) {
            lastSupplierId = supplierId
        }
        if let recent = defaults.array(forKey: "recent_products_\(restaurantId)") as? [String] {
            recentProductIds = recent.compactMap(UUID.init(uuidString:))
        }
    }

    func persistMemory(restaurantId: UUID) {
        let defaults = UserDefaults.standard
        defaults.set(selectedSupplier?.id.uuidString, forKey: "last_supplier_\(restaurantId)")
        defaults.set(recentProductIds.map(\.uuidString), forKey: "recent_products_\(restaurantId)")
    }

    func setProduct(_ product: ProductTemplate) {
        selectedProduct = product
        showControlSheet = true
        if recentProductIds.contains(product.id) == false {
            recentProductIds.insert(product.id, at: 0)
        }
        recentProductIds = Array(recentProductIds.prefix(8))
    }

    func resetForNext() {
        selectedProduct = nil
        showControlSheet = false
    }
}
