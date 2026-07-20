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
    /// Giorni di conservazione (opzionale; se `nil` si usa la mappa `IncomingFoodShelfLifeDefaults`).
    var shelfLifeDays: Int?
    var createdAt: Date

    var category: GoodsCategory {
        get { GoodsCategory(rawValue: categoryRaw) ?? .all }
        set { categoryRaw = newValue.rawValue }
    }

    /// Nome categoria visualizzato (supporta anche categorie personalizzate non in `GoodsCategory`).
    var categoryDisplayName: String { categoryRaw }

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
        shelfLifeDays: Int? = nil,
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
        self.shelfLifeDays = shelfLifeDays
        self.createdAt = createdAt
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        categoryName: String,
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
        shelfLifeDays: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.categoryRaw = categoryName
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
        self.shelfLifeDays = shelfLifeDays
        self.createdAt = createdAt
    }
}
