import SwiftUI
import SwiftData

struct DefrostView: View {
    @EnvironmentObject var appState: AppState
    @Query private var records: [DefrostRecord]
    @StateObject private var vm = DefrostViewModel()

    private var scopedRecords: [DefrostRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Decongelamento") {
                if scopedRecords.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun decongelamento registrato",
                        message: "Le registrazioni con metodo e operatore appariranno qui.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedRecords.prefix(25)) { record in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.productName).foregroundColor(.white)
                                Text("Metodo: \(record.method)").font(.caption).foregroundColor(.gray)
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
        .navigationTitle("Decongelamento")
    }
}
