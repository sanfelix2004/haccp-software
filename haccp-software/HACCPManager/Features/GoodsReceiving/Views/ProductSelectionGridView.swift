import SwiftUI

struct ProductSelectionGridView: View {
    let products: [ProductTemplate]
    let recentProductIds: [UUID]
    let selectedProductId: UUID?
    let onSelect: (ProductTemplate) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            ForEach(products) { product in
                Button {
                    onSelect(product)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text(product.category.rawValue)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedProductId == product.id ? Color.red :
                                Color.white.opacity(0.08),
                                lineWidth: selectedProductId == product.id ? 2 : 1
                            )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
