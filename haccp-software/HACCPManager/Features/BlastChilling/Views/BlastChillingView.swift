import SwiftUI
import SwiftData

struct BlastChillingView: View {
    @EnvironmentObject var appState: AppState
    @Query private var records: [BlastChillingRecord]
    @StateObject private var vm = BlastChillingViewModel()

    private var scopedRecords: [BlastChillingRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Abbattimento in negativo") {
                if scopedRecords.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun abbattimento registrato",
                        message: "Le registrazioni di abbattimento appariranno qui.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedRecords.prefix(25)) { record in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.productName).foregroundColor(.white)
                                Text("Inizio \(record.initialTemperature, specifier: "%.1f")°C · Fine \(record.finalTemperature, specifier: "%.1f")°C")
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
        .navigationTitle("Abbattimento")
    }
}
