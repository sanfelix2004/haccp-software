import Foundation
import SwiftUI

struct AnalyticsService {
    func checklistWeeklyPoints(
        restaurantId: UUID,
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        alerts: [ChecklistAlert],
        now: Date = Date()
    ) -> [ChecklistChartPoint] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let scopedRuns = runs.filter { $0.restaurantId == restaurantId && $0.startedAt >= start }
        let resultsByRun = Dictionary(grouping: itemResults, by: \.checklistRunId)
        let activeAlertsByRun = Dictionary(
            grouping: alerts.filter { $0.restaurantId == restaurantId && $0.isActive },
            by: \.checklistRunId
        )

        return (0..<7).compactMap { offset -> ChecklistChartPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            let dayRuns = scopedRuns.filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }

            let totals = dayRuns.reduce(into: (completed: 0, total: 0, completedRuns: 0, overdue: 0, criticalOpen: 0)) { acc, run in
                let runResults = resultsByRun[run.id] ?? []
                let completed = runResults.filter {
                    $0.result == .pass || $0.result == .fail || $0.result == .notApplicable
                }.count
                acc.completed += completed
                acc.total += runResults.count
                if run.status == .completed { acc.completedRuns += 1 }
                if run.status == .overdue { acc.overdue += 1 }
                acc.criticalOpen += (activeAlertsByRun[run.id]?.count ?? 0)
            }

            let percentage = totals.total == 0 ? 0 : (Double(totals.completed) / Double(totals.total) * 100)
            let label = day.formatted(.dateTime.weekday(.abbreviated))
            return ChecklistChartPoint(
                dayStart: dayStart,
                dayLabel: label.capitalized,
                completionPercentage: percentage,
                completedRuns: totals.completedRuns,
                overdueRuns: totals.overdue,
                criticalOpen: totals.criticalOpen
            )
        }
    }

    func checklistKPIs(points: [ChecklistChartPoint], alerts: [ChecklistAlert], restaurantId: UUID) -> [AnalyticsKPI] {
        let avg = points.isEmpty ? 0 : (points.map(\.completionPercentage).reduce(0, +) / Double(points.count))
        let completed = points.map(\.completedRuns).reduce(0, +)
        let overdue = points.map(\.overdueRuns).reduce(0, +)
        let critical = alerts.filter { $0.restaurantId == restaurantId && $0.isActive }.count

        return [
            AnalyticsKPI(title: "Completamento medio", value: "\(Int(avg.rounded()))%", color: .green),
            AnalyticsKPI(title: "Checklist completate", value: "\(completed)", color: .green),
            AnalyticsKPI(title: "Checklist in ritardo", value: "\(overdue)", color: overdue > 0 ? .yellow : .gray),
            AnalyticsKPI(title: "Criticita aperte", value: "\(critical)", color: critical > 0 ? .red : .gray)
        ]
    }

    func temperaturePoints(
        restaurantId: UUID,
        records: [TemperatureRecord],
        period: AnalyticsPeriod,
        deviceId: UUID?,
        now: Date = Date()
    ) -> [TemperatureChartPoint] {
        let start = period.startDate(now: now)
        return records
            .filter { $0.restaurantId == restaurantId && $0.measuredAt >= start }
            .filter { record in
                guard let deviceId else { return true }
                return record.deviceId == deviceId
            }
            .sorted(by: { $0.measuredAt < $1.measuredAt })
            .map { record in
                TemperatureChartPoint(
                    timestamp: record.measuredAt,
                    value: record.value,
                    minAllowed: record.minAllowed,
                    maxAllowed: record.maxAllowed,
                    isOutOfRange: record.value < record.minAllowed || record.value > record.maxAllowed
                )
            }
    }

    func temperatureKPIs(points: [TemperatureChartPoint]) -> [AnalyticsKPI] {
        guard !points.isEmpty else {
            return [
                AnalyticsKPI(title: "Ultima temperatura", value: "--", color: .gray),
                AnalyticsKPI(title: "Media periodo", value: "--", color: .gray),
                AnalyticsKPI(title: "Fuori range", value: "--", color: .gray),
                AnalyticsKPI(title: "Massima", value: "--", color: .gray),
                AnalyticsKPI(title: "Minima", value: "--", color: .gray)
            ]
        }

        let values = points.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        let out = points.filter(\.isOutOfRange).count
        let last = points.last?.value ?? 0
        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0

        return [
            AnalyticsKPI(title: "Ultima temperatura", value: format(last), color: .white),
            AnalyticsKPI(title: "Media periodo", value: format(avg), color: .yellow),
            AnalyticsKPI(title: "Fuori range", value: "\(out)", color: out > 0 ? .red : .green),
            AnalyticsKPI(title: "Massima", value: format(maxValue), color: .red),
            AnalyticsKPI(title: "Minima", value: format(minValue), color: .green)
        ]
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f °C", value)
    }
}
