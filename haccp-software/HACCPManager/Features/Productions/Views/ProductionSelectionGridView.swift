import SwiftUI

struct ProductionSelectionGridView: View {
    let layout: ProductionCatalogPresentation
    let selectedProductionId: UUID?
    var showsShelfLife: Bool = false
    let onSelect: (Production) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if layout.usesSectionHeaders {
                sectionedGrid
            } else {
                flatGrid(productions: layout.flatProductions)
            }
        }
    }

    private var sectionedGrid: some View {
        LazyVStack(alignment: .leading, spacing: theme.spacing.lg) {
            ForEach(layout.sections) { section in
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
                productionCard(production, showsCategory: layout.showsCategoryOnCard)
            }
        }
    }

    private func productionCard(_ production: Production, showsCategory: Bool) -> some View {
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
                    if showsCategory {
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

extension ProductionSelectionGridView {
    /// Compatibilità schermate che passano array grezzi (es. Abbattimento).
    init(
        productions: [Production],
        categories: [ProductionCategory] = [],
        recentProductionIds: [UUID] = [],
        selectedProductionId: UUID?,
        groupsByCategory: Bool = false,
        showsShelfLife: Bool = false,
        onSelect: @escaping (Production) -> Void
    ) {
        let sorted = productions.sorted { lhs, rhs in
            let lhsRecent = recentProductionIds.firstIndex(of: lhs.id) ?? Int.max
            let rhsRecent = recentProductionIds.firstIndex(of: rhs.id) ?? Int.max
            if lhsRecent != rhsRecent { return lhsRecent < rhsRecent }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        self.init(
            layout: ProductionCatalogPresentation.build(
                categories: categories,
                productions: sorted,
                selectedCategoryId: nil,
                forceFlat: !groupsByCategory
            ),
            selectedProductionId: selectedProductionId,
            showsShelfLife: showsShelfLife,
            onSelect: onSelect
        )
    }
}
