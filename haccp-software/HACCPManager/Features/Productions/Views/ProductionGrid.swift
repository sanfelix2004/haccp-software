import SwiftUI

struct ProductionGrid: View {
    let productions: [Production]
    let selectedProductionIds: Set<UUID>
    let isEditMode: Bool
    let onSelect: (Production) -> Void
    let onDelete: (Production) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(productions) { production in
                Button {
                    onSelect(production)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(production.name)
                            .font(.headline)
                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                            .lineLimit(2)
                        Text(production.categoryNameSnapshot)
                            .font(.caption2)
                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                    .padding(10)
                    .background(ThemeManager.shared.colorSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedProductionIds.contains(production.id) ? Color.red : ThemeManager.shared.colorDivider, lineWidth: selectedProductionIds.contains(production.id) ? 2 : 1)
                    )
                    .cornerRadius(12)
                    .overlay(alignment: .topTrailing) {
                        if selectedProductionIds.contains(production.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ThemeManager.shared.colorSuccess)
                                .padding(8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
