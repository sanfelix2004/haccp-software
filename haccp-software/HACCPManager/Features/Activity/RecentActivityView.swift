import SwiftUI
import SwiftData

struct RecentActivityView: View {
    @EnvironmentObject var appState: AppState
    @Query private var checklistLogs: [ChecklistAuditLog]
    @Query private var temperatureLogs: [TemperatureAuditLog]

    private var activityRows: [(title: String, date: Date)] {
        guard let rid = appState.activeRestaurantId else { return [] }
        let checklist = checklistLogs
            .filter { $0.restaurantId == rid }
            .map { ("\($0.userName): \($0.action)", $0.timestamp) }
        let temperature = temperatureLogs
            .filter { $0.restaurantId == rid }
            .map { ("\($0.userName): \($0.action)", $0.createdAt) }
        return (checklist + temperature).sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Attivita recenti") {
                if activityRows.isEmpty {
                    DashboardEmptyStateView(
                        state: DashboardEmptyState(
                            title: "Nessuna attivita registrata",
                            message: "Lo storico apparira qui quando saranno disponibili dati reali",
                            actionTitle: nil
                        )
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(activityRows.prefix(30).enumerated()), id: \.offset) { _, row in
                            HStack {
                                Image(systemName: "clock.arrow.circlepath").foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text(row.title).foregroundColor(.white)
                                    Text(row.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
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
        .navigationTitle("Attivita recenti")
    }
}
