import SwiftUI
import SwiftData

struct TraceabilityView: View {
    @EnvironmentObject var appState: AppState
    @Query private var records: [TraceabilityRecord]
    @StateObject private var vm = TraceabilityViewModel()

    private var scopedRecords: [TraceabilityRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Tracciabilita") {
                if scopedRecords.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna registrazione disponibile",
                        message: "Registra prodotti e lotti ricevuti per attivare la tracciabilita.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedRecords.prefix(40)) { record in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.productName).foregroundColor(.white)
                                Text("Lotto: \(record.lotCode) · Fornitore: \(record.supplier)")
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
        .navigationTitle("Tracciabilita")
    }
}
