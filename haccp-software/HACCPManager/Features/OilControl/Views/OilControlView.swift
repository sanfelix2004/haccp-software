import SwiftUI
import SwiftData

struct OilControlView: View {
    @EnvironmentObject var appState: AppState
    @Query private var records: [OilControlRecord]
    @StateObject private var vm = OilControlViewModel()

    private var scopedRecords: [OilControlRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Controllo olio") {
                if scopedRecords.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun controllo olio registrato",
                        message: "I controlli olio con azioni e firma operatore appariranno qui.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedRecords.prefix(25)) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.oilState).foregroundColor(.white)
                                    Text(record.actionTaken).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                if let indexValue = record.indexValue {
                                    Text("\(indexValue, specifier: "%.1f")").foregroundColor(.yellow)
                                }
                            }
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
        .navigationTitle("Controllo olio")
    }
}
