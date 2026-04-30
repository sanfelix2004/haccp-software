import Foundation

struct GoodsReceiptRequirementService {
    func makeRequirement(for product: ProductTemplate) -> GoodsReceiptRequirement {
        var items: [GoodsChecklistTemplateItem] = [.orderConformity]

        if product.requiresAppearanceCheck || product.category == .produce || product.category == .perishable {
            items.append(.productAppearance)
        }
        if product.requiresPackagingCheck || product.category == .packaged || product.category == .dryProducts || product.category == .longShelfLife {
            items.append(.packageState)
        }
        if product.requiresExpiry || product.category == .packaged || product.category == .perishable || product.category == .longShelfLife || product.category == .dryProducts {
            items.append(.expiryDate)
        }
        if product.requiresThawingCheck || product.category == .frozen || product.category == .frozenProducts {
            items.append(.noThawingSigns)
        }
        if product.requiresMoldCheck || product.category == .produce {
            items.append(.noMold)
        }
        if product.requiresFreshnessCheck || product.category == .produce {
            items.append(.freshness)
        }

        let requiresTemperature = product.requiresTemperature || product.category.isColdChain
        if requiresTemperature {
            items.append(.temperatureCompliant)
        }

        let defaultMin: Double? = {
            if let min = product.defaultMinTemp { return min }
            if product.category == .refrigerated || product.category == .freshMeat || product.category == .freshFish { return 0 }
            return nil
        }()
        let defaultMax: Double? = {
            if let max = product.defaultMaxTemp { return max }
            if product.category == .frozen || product.category == .frozenProducts { return -18 }
            if product.category == .refrigerated || product.category == .freshMeat || product.category == .freshFish { return 4 }
            return nil
        }()

        let uniqueItems = items.reduce(into: [GoodsChecklistTemplateItem]()) { partial, next in
            if partial.contains(next) == false { partial.append(next) }
        }

        return GoodsReceiptRequirement(
            requiresTemperature: requiresTemperature,
            requiresLot: product.requiresLot,
            requiresExpiryDate: product.requiresExpiry || [.packaged, .perishable, .longShelfLife, .dryProducts, .combined].contains(product.category),
            requiresProductionDate: product.category == .combined,
            requiresChecklist: true,
            requiresNotes: false,
            requiresPackagingCheck: items.contains(.packageState),
            requiresAppearanceCheck: items.contains(.productAppearance),
            defaultMinTemp: defaultMin,
            defaultMaxTemp: defaultMax,
            checklistItems: uniqueItems
        )
    }
}
