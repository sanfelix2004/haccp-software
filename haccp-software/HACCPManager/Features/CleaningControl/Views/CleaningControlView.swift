import SwiftUI
import SwiftData

struct CleaningControlView: View {
    @EnvironmentObject var appState: AppState
    @Query private var records: [CleaningRecord]
    @StateObject private var vm = CleaningControlViewModel()

    private var scopedRecords: [CleaningRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Controllo pulizia") {
                if scopedRecords.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun piano di pulizia registrato",
                        message: "Le aree, frequenze e firme operatore appariranno qui.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedRecords.prefix(30)) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.areaName).foregroundColor(.white)
                                    Text(record.frequency).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Text(record.completed ? "Completata" : "Da fare")
                                    .font(.caption.bold())
                                    .foregroundColor(record.completed ? .green : .yellow)
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
        .navigationTitle("Controllo pulizia")
    }
}
