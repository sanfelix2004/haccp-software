import SwiftUI

struct RecentActivityView: View {
    var body: some View {
        ScrollView {
            DashboardCardView(title: "Attivita recenti") {
                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessuna attivita registrata",
                        message: "Lo storico apparira qui quando saranno disponibili dati reali",
                        actionTitle: nil
                    )
                )
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Attivita recenti")
    }
}
