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
                                Text(label.productName).foregroundColor(.white)
                                Text("Produzione: \(label.productionDate.formatted(date: .abbreviated, time: .omitted)) · Scadenza: \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Etichette")
    }
}
