import SwiftUI

struct DashboardModulesSection: View {
    let modules: [DashboardModule]
    var onTapModule: (DashboardModule) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        DashboardCardView(title: DashboardSection.modules.rawValue) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(modules) { module in
                    Button {
                        onTapModule(module)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: module.icon)
                                .font(.title2)
                                .foregroundColor(.red)
                            Text(module.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(module.description)
                                .font(.subheadline)
                                .foregroundColor(Color.white.opacity(0.72))
                                .lineLimit(2)
                            Text(module.state.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(module.state.tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(module.state.tint.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
