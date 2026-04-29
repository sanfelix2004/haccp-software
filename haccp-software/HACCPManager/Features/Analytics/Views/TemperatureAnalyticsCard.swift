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
                AnalyticsPeriodPicker(selection: $selectedPeriod)

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
                            AxisValueLabel().foregroundStyle(.gray)
                        }
                    }
                    .chartXAxis {
                        AxisMarks {
                            AxisValueLabel(format: .dateTime.day().hour(), centered: true)
                                .foregroundStyle(.gray)
                        }
                    }

                    kpiGrid
                }
            }
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
