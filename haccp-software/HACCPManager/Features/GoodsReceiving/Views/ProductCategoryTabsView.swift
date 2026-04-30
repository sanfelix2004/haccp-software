import SwiftUI

struct ProductCategoryTabsView: View {
    @Binding var selectedCategory: GoodsCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(GoodsCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selectedCategory == category ? .red : .gray)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(selectedCategory == category ? Color.red : .clear)
                            .frame(height: 2)
                    }
                }
            }
        }
    }
}
