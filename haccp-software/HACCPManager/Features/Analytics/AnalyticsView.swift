import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        ScrollView {
            DashboardCardView(title: "Grafici e andamento") {
                VStack(alignment: .leading, spacing: 12) {
                    chartRow("Andamento temperature")
                    chartRow("Completamento checklist")
                    chartRow("Attivita per giorno")
                    chartRow("Criticita rilevate")
                    chartRow("Pulizie completate")
                    chartRow("Prodotti in scadenza")
                }

                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessun dato disponibile",
                        message: "I grafici appariranno quando saranno disponibili dati reali",
                        actionTitle: nil
                    )
                )
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Grafici")
    }

    private func chartRow(_ title: String) -> some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(.red)
            Text(title)
                .foregroundColor(.white)
            Spacer()
        }
    }
}
