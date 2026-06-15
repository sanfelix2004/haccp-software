import SwiftUI

struct BlastChillingProductionGridView: View {
    let productions: [Production]
    let selectedProductionId: UUID?
    let onSelect: (Production) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(productions) { production in
                Button {
                    onSelect(production)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
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
                            .stroke(selectedProductionId == production.id ? ThemeManager.shared.colorPrimary : ThemeManager.shared.colorDivider, lineWidth: selectedProductionId == production.id ? 2 : 1)
                    )
                    .cornerRadius(12)
                    .overlay(alignment: .topTrailing) {
                        if selectedProductionId == production.id {
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
