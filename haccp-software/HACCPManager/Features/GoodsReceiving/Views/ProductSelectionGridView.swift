import SwiftUI

struct ProductSelectionGridView: View {
    let layout: IncomingFoodCatalogPresentation
    let selectedProductId: UUID?
    let onSelect: (ProductTemplate) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if layout.usesSectionHeaders {
                sectionedGrid
            } else {
                flatGrid(products: layout.flatProducts)
            }
        }
    }

    private var sectionedGrid: some View {
        LazyVStack(alignment: .leading, spacing: theme.spacing.lg) {
            ForEach(layout.sections) { section in
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    HStack(spacing: 8) {
                        Text(section.category.rawValue)
                            .font(theme.typography.subheadline.weight(.bold))
                            .foregroundStyle(theme.colorTextPrimary)
                        Text("\(section.products.count)")
                            .font(theme.typography.caption2.weight(.semibold))
                            .foregroundStyle(theme.colorTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.colorDivider.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    flatGrid(products: section.products)
                }
            }
        }
    }

    private func flatGrid(products: [ProductTemplate]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(products) { product in
                productCard(product, showsCategory: layout.showsCategoryOnCard)
            }
        }
    }

    private func productCard(_ product: ProductTemplate, showsCategory: Bool) -> some View {
        let isSelected = selectedProductId == product.id

        return Button {
            onSelect(product)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(product.name)
                        .font(theme.typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.colorPrimary)
                    }
                }
                if showsCategory {
                    Text(product.category.rawValue)
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                        .lineLimit(1)
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

extension ProductSelectionGridView {
    init(
        products: [ProductTemplate],
        recentProductIds: [UUID] = [],
        selectedProductId: UUID?,
        groupsByCategory: Bool = true,
        onSelect: @escaping (ProductTemplate) -> Void
    ) {
        let sorted = products.sorted { lhs, rhs in
            let lhsRecent = recentProductIds.firstIndex(of: lhs.id) ?? Int.max
            let rhsRecent = recentProductIds.firstIndex(of: rhs.id) ?? Int.max
            if lhsRecent != rhsRecent { return lhsRecent < rhsRecent }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        self.init(
            layout: IncomingFoodCatalogPresentation.build(
                templates: sorted,
                selectedCategory: groupsByCategory ? .all : .all
            ),
            selectedProductId: selectedProductId,
            onSelect: onSelect
        )
    }
}
