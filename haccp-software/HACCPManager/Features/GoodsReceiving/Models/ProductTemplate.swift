import Foundation
import SwiftData

enum GoodsCategory: String, Codable, CaseIterable, Identifiable {
    case all = "Tutti"
    case longShelfLife = "Alimenti a lunga conservazione"
    case combined = "Alimenti combinati"
    case frozen = "Alimenti congelati"
    case perishable = "Alimenti deperibili"
    case refrigerated = "Alimenti refrigerati"
    case packaged = "Prodotti confezionati"
    case produce = "Prodotti ortofrutticoli"
    case dryProducts = "Prodotti secchi"
    case frozenProducts = "Prodotti surgelati"
    case freshMeat = "Carni fresche"
    case freshFish = "Pesce fresco"

    var id: String { rawValue }

    var isColdChain: Bool {
        switch self {
        case .frozen, .refrigerated, .frozenProducts, .freshMeat, .freshFish:
            return true
        default:
            return false
        }
    }
}

@Model
final class ProductTemplate {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var categoryRaw: String
    var defaultMinTemp: Double?
    var defaultMaxTemp: Double?
    var requiresTemperature: Bool
    var requiresLot: Bool
    var requiresExpiry: Bool
    var requiresPackagingCheck: Bool = true
    var requiresAppearanceCheck: Bool = false
    var requiresThawingCheck: Bool = false
    var requiresMoldCheck: Bool = false
    var requiresFreshnessCheck: Bool = false
    var createdAt: Date

    var category: GoodsCategory {
        get { GoodsCategory(rawValue: categoryRaw) ?? .all }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        category: GoodsCategory,
        defaultMinTemp: Double? = nil,
        defaultMaxTemp: Double? = nil,
        requiresTemperature: Bool = false,
        requiresLot: Bool = false,
        requiresExpiry: Bool = false,
        requiresPackagingCheck: Bool = true,
        requiresAppearanceCheck: Bool = false,
        requiresThawingCheck: Bool = false,
        requiresMoldCheck: Bool = false,
        requiresFreshnessCheck: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.categoryRaw = category.rawValue
        self.defaultMinTemp = defaultMinTemp
        self.defaultMaxTemp = defaultMaxTemp
        self.requiresTemperature = requiresTemperature
        self.requiresLot = requiresLot
        self.requiresExpiry = requiresExpiry
        self.requiresPackagingCheck = requiresPackagingCheck
        self.requiresAppearanceCheck = requiresAppearanceCheck
        self.requiresThawingCheck = requiresThawingCheck
        self.requiresMoldCheck = requiresMoldCheck
        self.requiresFreshnessCheck = requiresFreshnessCheck
        self.createdAt = createdAt
    }
}
