import SwiftUI
import SwiftData

struct ProductionLabelsView: View {
    @EnvironmentObject var appState: AppState
    @Query private var labels: [ProductionLabelRecord]
    @StateObject private var vm = ProductionLabelsViewModel()

    private var scopedLabels: [ProductionLabelRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return labels.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Etichette di produzione") {
                if scopedLabels.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna etichetta disponibile",
                        message: "Le etichette generate e il loro storico appariranno qui.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedLabels.prefix(30)) { label in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(label.productName).foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                Text("Produzione: \(label.productionDate.formatted(date: .abbreviated, time: .omitted)) · Scadenza: \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(ThemeManager.shared.colorSurface)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Etichette")
    }
}
