//
//  IncomingFoodCatalogPresentation.swift
//

import Foundation

struct IncomingFoodCatalogGridSection: Identifiable {
    let id: String
    let categoryName: String
    let products: [ProductTemplate]
}

struct IncomingFoodCatalogPresentation {
    var sections: [IncomingFoodCatalogGridSection] = []
    var flatProducts: [ProductTemplate] = []
    var usesSectionHeaders = false
    var showsCategoryOnCard = true

    static let empty = IncomingFoodCatalogPresentation()

    /// - Parameter selectedCategoryName: `nil` = Tutti
    static func build(
        templates: [ProductTemplate],
        categories: [IncomingFoodCategory],
        selectedCategoryName: String?
    ) -> IncomingFoodCatalogPresentation {
        guard !templates.isEmpty else { return .empty }

        let sorted = templates.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var presentation = IncomingFoodCatalogPresentation()

        if let selectedCategoryName, !selectedCategoryName.isEmpty {
            presentation.flatProducts = sorted.filter {
                $0.categoryRaw.caseInsensitiveCompare(selectedCategoryName) == .orderedSame
            }
            presentation.sections = presentation.flatProducts.isEmpty ? [] : [
                IncomingFoodCatalogGridSection(
                    id: selectedCategoryName,
                    categoryName: selectedCategoryName,
                    products: presentation.flatProducts
                )
            ]
            presentation.usesSectionHeaders = false
            presentation.showsCategoryOnCard = true
            return presentation
        }

        let orderedNames = categories
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(\.name)
        var seen = Set(orderedNames.map { $0.lowercased() })
        var allNames = orderedNames
        for template in sorted {
            let key = template.categoryRaw.lowercased()
            if !key.isEmpty, !seen.contains(key) {
                seen.insert(key)
                allNames.append(template.categoryRaw)
            }
        }

        var sections: [IncomingFoodCatalogGridSection] = []
        for name in allNames {
            let items = sorted.filter {
                $0.categoryRaw.caseInsensitiveCompare(name) == .orderedSame
            }
            guard !items.isEmpty else { continue }
            sections.append(
                IncomingFoodCatalogGridSection(
                    id: name,
                    categoryName: name,
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

    /// Compatibilità con filtri ancora basati su `GoodsCategory`.
    static func build(
        templates: [ProductTemplate],
        selectedCategory: GoodsCategory
    ) -> IncomingFoodCatalogPresentation {
        build(
            templates: templates,
            categories: GoodsCategory.allCases
                .filter { $0 != .all }
                .enumerated()
                .map {
                    IncomingFoodCategory(
                        restaurantId: UUID(),
                        name: $0.element.rawValue,
                        orderIndex: $0.offset
                    )
                },
            selectedCategoryName: selectedCategory == .all ? nil : selectedCategory.rawValue
        )
    }
}
