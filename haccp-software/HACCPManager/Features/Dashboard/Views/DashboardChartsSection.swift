import SwiftUI

struct DashboardChartsSection: View {
    let chartTypes: [DashboardChartType]

    var body: some View {
        DashboardCardView(title: DashboardSection.charts.rawValue) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(chartTypes) { chart in
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.red)
                        Text(chart.rawValue)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessun dato disponibile",
                        message: "I grafici appariranno quando saranno disponibili dati reali",
                        actionTitle: nil
                    )
                )
            }
        }
    }
}
