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
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text(production.categoryNameSnapshot)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedProductionIds.contains(production.id) ? Color.red : Color.white.opacity(0.1), lineWidth: selectedProductionIds.contains(production.id) ? 2 : 1)
                    )
                    .cornerRadius(12)
                    .overlay(alignment: .topTrailing) {
                        if isEditMode && production.isCustom {
                            Button(role: .destructive) { onDelete(production) } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .padding(6)
                        } else if selectedProductionIds.contains(production.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
