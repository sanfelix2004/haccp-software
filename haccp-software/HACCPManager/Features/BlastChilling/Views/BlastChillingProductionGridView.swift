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
                            .stroke(selectedProductionId == production.id ? Color.green : Color.white.opacity(0.1), lineWidth: selectedProductionId == production.id ? 2 : 1)
                    )
                    .cornerRadius(12)
                    .overlay(alignment: .topTrailing) {
                        if selectedProductionId == production.id {
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
