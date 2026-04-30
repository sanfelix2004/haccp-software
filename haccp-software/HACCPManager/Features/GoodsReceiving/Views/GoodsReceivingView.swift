import SwiftUI
import SwiftData

struct GoodsReceivingView: View {
    @EnvironmentObject var appState: AppState
    @Query private var records: [GoodsReceivingRecord]
    @StateObject private var vm = GoodsReceivingViewModel()

    private var scopedRecords: [GoodsReceivingRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Ricezione merci") {
                if scopedRecords.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna ricezione registrata",
                        message: "Le registrazioni merci con conformita e note appariranno qui.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedRecords.prefix(30)) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.productName).foregroundColor(.white)
                                    Text(record.supplier).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Text(record.compliant ? "Conforme" : "Non conforme")
                                    .font(.caption.bold())
                                    .foregroundColor(record.compliant ? .green : .red)
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
        .navigationTitle("Ricezione merci")
    }
}
