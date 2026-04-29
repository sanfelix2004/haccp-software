import SwiftUI
import Charts

struct ChecklistAnalyticsCard: View {
    let points: [ChecklistChartPoint]
    let kpis: [AnalyticsKPI]

    var body: some View {
        DashboardCardView(title: "Andamento checklist") {
            if points.allSatisfy({ $0.completedRuns == 0 && $0.overdueRuns == 0 && $0.criticalOpen == 0 && $0.completionPercentage == 0 }) {
                AnalyticsEmptyStateView(
                    title: "Nessun dato checklist disponibile",
                    message: "Compila almeno una checklist per visualizzare l'andamento."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Chart(points) { point in
                        BarMark(
                            x: .value("Giorno", point.dayLabel),
                            y: .value("Completamento", point.completionPercentage)
                        )
                        .foregroundStyle(point.completionPercentage >= 80 ? .green : (point.completionPercentage >= 50 ? .yellow : .red))
                        .cornerRadius(4)
                    }
                    .frame(height: 220)
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            AxisValueLabel {
                                if let value = $0.as(Int.self) {
                                    Text("\(value)%").foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks {
                            AxisValueLabel().foregroundStyle(.gray)
                        }
                    }

                    kpiGrid
                }
            }
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(kpis) { kpi in
                VStack(alignment: .leading, spacing: 4) {
                    Text(kpi.title)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(kpi.value)
                        .font(.headline)
                        .foregroundColor(kpi.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
}
