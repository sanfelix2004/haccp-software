import SwiftUI
import Charts

struct TemperatureAnalyticsCard: View {
    let points: [TemperatureChartPoint]
    let kpis: [AnalyticsKPI]
    let devices: [TemperatureDevice]
    @Binding var selectedDeviceId: UUID?
    @Binding var selectedPeriod: AnalyticsPeriod

    var body: some View {
        DashboardCardView(title: "Andamento temperature") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TemperatureDevicePicker(devices: devices, selectedDeviceId: $selectedDeviceId)
                    Spacer()
                }

                if points.isEmpty {
                    AnalyticsEmptyStateView(
                        title: "Nessun dato temperatura disponibile",
                        message: "Registra misurazioni per visualizzare il grafico."
                    )
                } else {
                    Chart {
                        ForEach(points) { point in
                            LineMark(
                                x: .value("Data", point.timestamp),
                                y: .value("Temperatura", point.value)
                            )
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Data", point.timestamp),
                                y: .value("Temperatura", point.value)
                            )
                            .foregroundStyle(point.isOutOfRange ? .red : .green)
                            .symbolSize(point.isOutOfRange ? 80 : 35)
                        }
                        if let first = points.first {
                            RuleMark(y: .value("Min", first.minAllowed))
                                .foregroundStyle(.yellow.opacity(0.8))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            RuleMark(y: .value("Max", first.maxAllowed))
                                .foregroundStyle(.yellow.opacity(0.8))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        }
                    }
                    .frame(height: 240)
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            AxisValueLabel().foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks {
                            AxisValueLabel(format: .dateTime.day().hour(), centered: true)
                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        }
                    }

                    kpiGrid
                }
            }
        }
    }

    private var kpiGrid: some View {
        AnalyticsKPIGrid(kpis: kpis, columns: 3)
    }
}
