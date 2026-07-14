//
//  ProductionCatalogPresentation.swift
//  Layout pre-calcolato — evita sort/filter O(n²) ad ogni frame SwiftUI.
//

import Foundation

struct ProductionCatalogGridSection: Identifiable {
    let id: UUID
    let name: String
    let productions: [Production]
}

struct ProductionCatalogPresentation {
    var sections: [ProductionCatalogGridSection] = []
    var flatProductions: [Production] = []
    var usesSectionHeaders = false
    var showsCategoryOnCard = true
    var categoryOrderById: [UUID: Int] = [:]

    static let empty = ProductionCatalogPresentation()

    static func build(
        categories: [ProductionCategory],
        productions: [Production],
        selectedCategoryId: UUID?,
        forceFlat: Bool = false
    ) -> ProductionCatalogPresentation {
        guard !productions.isEmpty else { return .empty }

        var presentation = ProductionCatalogPresentation()
        presentation.categoryOrderById = HACCPSafeParse.dictionary(
            categories.map { ($0.id, $0.orderIndex) }
        )

        if forceFlat {
            presentation.flatProductions = productions.sorted { sortByName($0, $1) }
            presentation.sections = [
                ProductionCatalogGridSection(
                    id: UUID(),
                    name: "Piatti",
                    productions: presentation.flatProductions
                )
            ]
            presentation.usesSectionHeaders = false
            presentation.showsCategoryOnCard = true
            return presentation
        }

        let sortedCategories = categories.sorted { $0.orderIndex < $1.orderIndex }
        let filtered: [Production]
        if let selectedCategoryId {
            filtered = productions
                .filter { $0.categoryId == selectedCategoryId }
                .sorted { sortByName($0, $1) }
            presentation.flatProductions = filtered
            presentation.sections = filtered.isEmpty ? [] : [
                ProductionCatalogGridSection(
                    id: selectedCategoryId,
                    name: sortedCategories.first(where: { $0.id == selectedCategoryId })?.name ?? "Categoria",
                    productions: filtered
                )
            ]
            presentation.usesSectionHeaders = false
            presentation.showsCategoryOnCard = true
            return presentation
        }

        let sortedProductions = productions.sorted { lhs, rhs in
            let lhsOrder = presentation.categoryOrderById[lhs.categoryId] ?? Int.max
            let rhsOrder = presentation.categoryOrderById[rhs.categoryId] ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return sortByName(lhs, rhs)
        }
        presentation.flatProductions = sortedProductions

        var sections: [ProductionCatalogGridSection] = []
        for category in sortedCategories {
            let items = sortedProductions.filter { $0.categoryId == category.id }
            guard !items.isEmpty else { continue }
            sections.append(
                ProductionCatalogGridSection(id: category.id, name: category.name, productions: items)
            )
        }
        if sections.isEmpty, !sortedProductions.isEmpty {
            sections = [
                ProductionCatalogGridSection(
                    id: UUID(),
                    name: "Piatti",
                    productions: sortedProductions
                )
            ]
        }
        presentation.sections = sections
        presentation.usesSectionHeaders = sections.count > 1
        presentation.showsCategoryOnCard = !presentation.usesSectionHeaders
        return presentation
    }

    private static func sortByName(_ lhs: Production, _ rhs: Production) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
