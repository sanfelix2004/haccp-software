import SwiftUI
import Charts

// MARK: - KPI

struct AnalyticsKPIGrid: View {
    let kpis: [AnalyticsKPI]
    var columns: Int = 2

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: columns),
            spacing: 10
        ) {
            ForEach(kpis) { kpi in
                VStack(alignment: .leading, spacing: 4) {
                    Text(kpi.title)
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    Text(kpi.value)
                        .font(.headline)
                        .foregroundStyle(kpi.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(ThemeManager.shared.colorSurface)
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Barre giornaliere

struct AnalyticsDailyBarChart: View {
    let points: [AnalyticsDailyPoint]
    var height: CGFloat = 220
    var yAxisSuffix: String = ""
    var barColor: Color = ThemeManager.shared.colorPrimary
    var valueFormat: (Double) -> String = { String(format: "%.0f", $0) }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Giorno", point.label),
                y: .value("Valore", point.value)
            )
            .foregroundStyle(barColor.gradient)
            .cornerRadius(4)
            .annotation(position: .top, spacing: 2) {
                if point.value > 0 {
                    Text(valueFormat(point.value))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                }
            }
        }
        .frame(height: height)
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.25))
                AxisValueLabel().foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(points.count, 8))) {
                AxisValueLabel().foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
    }
}

struct AnalyticsStackedBarChart: View {
    let points: [AnalyticsBarSeriesPoint]
    var height: CGFloat = 220

    private var seriesColors: [String: Color] {
        [
            "Conforme": ThemeManager.shared.colorSuccess,
            "Completate": ThemeManager.shared.colorSuccess,
            "Pulito": ThemeManager.shared.colorSuccess,
            "Disponibile": ThemeManager.shared.colorSuccess,
            "Non conforme": ThemeManager.shared.colorError,
            "In ritardo": ThemeManager.shared.colorWarning,
            "Non pulito": ThemeManager.shared.colorError,
            "N/A": ThemeManager.shared.colorTextSecondary.opacity(0.6),
            "Da monitorare": ThemeManager.shared.colorWarning,
            "Scaduto": ThemeManager.shared.colorError,
            "Respinto": ThemeManager.shared.colorError,
            "Da fare": ThemeManager.shared.colorTextSecondary,
            "Etichette": ThemeManager.shared.colorInfo
        ]
    }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Giorno", point.dayLabel),
                y: .value("Valore", point.value)
            )
            .foregroundStyle(by: .value("Serie", point.series))
            .cornerRadius(3)
        }
        .frame(height: height)
        .chartForegroundStyleScale(
            domain: Array(Set(points.map(\.series))).sorted(),
            range: Array(Set(points.map(\.series))).sorted().map { seriesColors[$0] ?? ThemeManager.shared.colorPrimary }
        )
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.25))
                AxisValueLabel().foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) {
                AxisValueLabel().foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
    }
}

// MARK: - Settori

struct AnalyticsSectorChart: View {
    let slices: [AnalyticsSlicePoint]
    var height: CGFloat = 200

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Valore", slice.value),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .foregroundStyle(slice.color)
            .cornerRadius(4)
        }
        .frame(height: height)
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
    }
}

// MARK: - Linea generica

struct AnalyticsLineChart: View {
    let points: [AnalyticsLinePoint]
    var height: CGFloat = 220
    var lineColor: Color = ThemeManager.shared.colorPrimary
    var highlightColor: Color = ThemeManager.shared.colorError
    var valueSuffix: String = ""

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Data", point.timestamp),
                    y: .value("Valore", point.value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Data", point.timestamp),
                    y: .value("Valore", point.value)
                )
                .foregroundStyle(point.isHighlighted ? highlightColor : lineColor)
                .symbolSize(point.isHighlighted ? 70 : 30)
            }
        }
        .frame(height: height)
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.25))
                AxisValueLabel().foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
        .chartXAxis {
            AxisMarks {
                AxisValueLabel(format: .dateTime.day().month(), centered: true)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
    }
}

// MARK: - Card modulo

struct AnalyticsModuleCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let accent: Color
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        accent: Color = ThemeManager.shared.colorPrimary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.content = content
    }

    var body: some View {
        DashboardCardView(title: title, subtitle: subtitle) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
            }
            content()
        }
    }
}
