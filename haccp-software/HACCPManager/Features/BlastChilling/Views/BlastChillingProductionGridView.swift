import SwiftUI

struct BlastChillingProductionGridView: View {
    let productions: [Production]
    var categories: [ProductionCategory] = []
    let selectedProductionId: UUID?
    var groupsByCategory: Bool = false
    var showsShelfLife: Bool = false
    let onSelect: (Production) -> Void

    var body: some View {
        ProductionSelectionGridView(
            productions: productions,
            categories: categories,
            recentProductionIds: [],
            selectedProductionId: selectedProductionId,
            groupsByCategory: groupsByCategory,
            showsShelfLife: showsShelfLife,
            onSelect: onSelect
        )
    }
}
