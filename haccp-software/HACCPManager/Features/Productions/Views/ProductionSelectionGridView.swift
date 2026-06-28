import SwiftUI

struct ProductionSelectionGridView: View {
    let productions: [Production]
    var categories: [ProductionCategory] = []
    let recentProductionIds: [UUID]
    let selectedProductionId: UUID?
    /// Raggruppa per categoria menu (es. Antipasti, Primi…).
    var groupsByCategory: Bool = true
    var showsShelfLife: Bool = false
    let onSelect: (Production) -> Void

    @Environment(\.theme) private var theme

    private var categorySections: [(id: UUID, name: String, orderIndex: Int, productions: [Production])] {
        let orderedCategories: [(id: UUID, name: String, orderIndex: Int)]
        if categories.isEmpty {
            orderedCategories = derivedCategories
        } else {
            orderedCategories = categories
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { ($0.id, $0.name, $0.orderIndex) }
        }

        return orderedCategories.compactMap { category in
            let items = sortedProductions.filter { $0.categoryId == category.id }
            guard !items.isEmpty else { return nil }
            return (category.id, category.name, category.orderIndex, items)
        }
    }

    private var derivedCategories: [(id: UUID, name: String, orderIndex: Int)] {
        var seen = Set<UUID>()
        var result: [(id: UUID, name: String, orderIndex: Int)] = []
        for production in sortedProductions {
            guard seen.insert(production.categoryId).inserted else { continue }
            result.append((production.categoryId, production.categoryNameSnapshot, result.count))
        }
        return result
    }

    private var sortedProductions: [Production] {
        productions.sorted { lhs, rhs in
            let lhsRecent = recentProductionIds.firstIndex(of: lhs.id) ?? Int.max
            let rhsRecent = recentProductionIds.firstIndex(of: rhs.id) ?? Int.max
            if lhsRecent != rhsRecent { return lhsRecent < rhsRecent }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if groupsByCategory, categorySections.count > 1 {
                sectionedGrid
            } else {
                flatGrid(productions: sortedProductions)
            }
        }
    }

    private var sectionedGrid: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            ForEach(categorySections, id: \.id) { section in
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    HStack(spacing: 8) {
                        Text(section.name)
                            .font(theme.typography.subheadline.weight(.bold))
                            .foregroundStyle(theme.colorTextPrimary)
                        Text("\(section.productions.count)")
                            .font(theme.typography.caption2.weight(.semibold))
                            .foregroundStyle(theme.colorTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.colorDivider.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    flatGrid(productions: section.productions)
                }
            }
        }
    }

    private func flatGrid(productions: [Production]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(productions) { production in
                productionCard(production)
            }
        }
    }

    private func productionCard(_ production: Production) -> some View {
        let isSelected = selectedProductionId == production.id

        return Button {
            onSelect(production)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(production.name)
                        .font(theme.typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.colorPrimary)
                    }
                }
                HStack(spacing: 6) {
                    if !groupsByCategory || categorySections.count <= 1 {
                        Text(production.categoryNameSnapshot)
                            .font(theme.typography.caption2)
                            .foregroundStyle(theme.colorTextSecondary)
                            .lineLimit(1)
                    }
                    if showsShelfLife {
                        Text("Durata \(production.catalogShelfLifeLabel)")
                            .font(theme.typography.caption2.weight(.semibold))
                            .foregroundStyle(theme.colorPrimary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .padding(12)
            .background(isSelected ? theme.colorPrimary.opacity(0.08) : theme.colorSurfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? theme.colorPrimary : theme.colorDivider,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}
