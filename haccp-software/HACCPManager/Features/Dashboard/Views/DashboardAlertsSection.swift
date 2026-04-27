import SwiftUI

struct DashboardAlertsSection: View {
    let alerts: [DashboardAlertItem]

    var body: some View {
        DashboardCardView(title: DashboardSection.alerts.rawValue) {
            if alerts.isEmpty {
                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessun alert attivo",
                        message: "Gli alert di temperatura, checklist e pulizie appariranno qui",
                        actionTitle: nil
                    )
                )
            } else {
                ForEach(alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.title)
                            .foregroundColor(.white)
                        Text(alert.detail)
                            .foregroundColor(Color.white.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}
