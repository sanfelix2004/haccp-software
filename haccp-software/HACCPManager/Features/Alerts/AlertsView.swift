import SwiftUI
import SwiftData

struct AlertsView: View {
    @EnvironmentObject var appState: AppState
    @Query private var checklistAlerts: [ChecklistAlert]
    @Query private var temperatureAlerts: [TemperatureAlert]

    private var activeChecklistAlerts: [ChecklistAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return checklistAlerts.filter { $0.restaurantId == rid && $0.isActive }
    }

    private var activeTemperatureAlerts: [TemperatureAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return temperatureAlerts.filter { $0.restaurantId == rid && $0.isActive }
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Alert") {
                if activeChecklistAlerts.isEmpty && activeTemperatureAlerts.isEmpty {
                    DashboardEmptyStateView(
                        state: DashboardEmptyState(
                            title: "Nessun alert attivo",
                            message: "Gli alert di temperatura, checklist e pulizie appariranno qui",
                            actionTitle: nil
                        )
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(activeChecklistAlerts) { alert in
                            alertRow(message: alert.message, date: alert.createdAt, icon: "checklist")
                        }
                        ForEach(activeTemperatureAlerts) { alert in
                            alertRow(message: alert.message, date: alert.createdAt, icon: "thermometer.medium")
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Alert")
    }

    private func alertRow(message: String, date: Date, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text(message).foregroundColor(.white)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}
