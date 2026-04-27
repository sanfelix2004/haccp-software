import SwiftUI

struct AlertsView: View {
    var body: some View {
        ScrollView {
            DashboardCardView(title: "Alert") {
                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessun alert attivo",
                        message: "Gli alert di temperatura, checklist e pulizie appariranno qui",
                        actionTitle: nil
                    )
                )
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Alert")
    }
}
