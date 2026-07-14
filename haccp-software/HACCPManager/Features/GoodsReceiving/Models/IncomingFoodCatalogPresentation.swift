//
//  IncomingFoodCatalogPresentation.swift
//

import Foundation

struct IncomingFoodCatalogGridSection: Identifiable {
    let id: String
    let category: GoodsCategory
    let products: [ProductTemplate]
}

struct IncomingFoodCatalogPresentation {
    var sections: [IncomingFoodCatalogGridSection] = []
    var flatProducts: [ProductTemplate] = []
    var usesSectionHeaders = false
    var showsCategoryOnCard = true

    static let empty = IncomingFoodCatalogPresentation()

    static func build(
        templates: [ProductTemplate],
        selectedCategory: GoodsCategory
    ) -> IncomingFoodCatalogPresentation {
        guard !templates.isEmpty else { return .empty }

        let sorted = templates.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var presentation = IncomingFoodCatalogPresentation()

        if selectedCategory != .all {
            presentation.flatProducts = sorted.filter { $0.category == selectedCategory }
            presentation.sections = presentation.flatProducts.isEmpty ? [] : [
                IncomingFoodCatalogGridSection(
                    id: selectedCategory.rawValue,
                    category: selectedCategory,
                    products: presentation.flatProducts
                )
            ]
            presentation.usesSectionHeaders = false
            presentation.showsCategoryOnCard = true
            return presentation
        }

        var sections: [IncomingFoodCatalogGridSection] = []
        for category in GoodsCategory.allCases where category != .all {
            let items = sorted.filter { $0.category == category }
            guard !items.isEmpty else { continue }
            sections.append(
                IncomingFoodCatalogGridSection(
                    id: category.rawValue,
                    category: category,
                    products: items
                )
            )
        }
        presentation.sections = sections
        presentation.flatProducts = sorted
        presentation.usesSectionHeaders = sections.count > 1
        presentation.showsCategoryOnCard = !presentation.usesSectionHeaders
        return presentation
    }
}
