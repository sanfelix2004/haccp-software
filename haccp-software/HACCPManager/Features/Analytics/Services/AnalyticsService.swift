import Foundation
import SwiftUI

struct AnalyticsService {

    // MARK: - Bucket giornalieri

    func dayBuckets(period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsDayBucket] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: period.startDate(now: now))
        let count: Int = {
            switch period {
            case .today: return 1
            case .sevenDays: return 7
            case .thirtyDays: return 30
            }
        }()

        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else {
                return nil
            }
            let label: String = {
                switch period {
                case .today:
                    return "Oggi"
                case .sevenDays:
                    return day.formatted(.dateTime.weekday(.abbreviated)).capitalized
                case .thirtyDays:
                    return day.formatted(.dateTime.day().month(.twoDigits))
                }
            }()
            return AnalyticsDayBucket(
                start: calendar.startOfDay(for: day),
                end: dayEnd,
                label: label
            )
        }
    }

    private func recordsInBucket<T>(
        _ records: [T],
        date: (T) -> Date,
        bucket: AnalyticsDayBucket
    ) -> [T] {
        records.filter { date($0) >= bucket.start && date($0) < bucket.end }
    }

    // MARK: - Checklist

    func checklistPoints(
        restaurantId: UUID,
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        alerts: [ChecklistAlert],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [ChecklistChartPoint] {
        let start = period.startDate(now: now)
        let scopedRuns = runs.filter { $0.restaurantId == restaurantId && $0.startedAt >= start }
        let resultsByRun = Dictionary(grouping: itemResults, by: \.checklistRunId)
        let activeAlertsByRun = Dictionary(
            grouping: alerts.filter { $0.restaurantId == restaurantId && $0.isActive },
            by: \.checklistRunId
        )

        return dayBuckets(period: period, now: now).map { bucket in
            let dayRuns = scopedRuns.filter { $0.startedAt >= bucket.start && $0.startedAt < bucket.end }
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
            return ChecklistChartPoint(
                dayStart: bucket.start,
                dayLabel: bucket.label,
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
            AnalyticsKPI(title: "In ritardo", value: "\(overdue)", color: overdue > 0 ? .yellow : .gray),
            AnalyticsKPI(title: "Criticità aperte", value: "\(critical)", color: critical > 0 ? .red : .gray)
        ]
    }

    // MARK: - Temperature

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
                AnalyticsKPI(title: "Ultima", value: "--", color: .gray),
                AnalyticsKPI(title: "Media", value: "--", color: .gray),
                AnalyticsKPI(title: "Fuori range", value: "--", color: .gray),
                AnalyticsKPI(title: "Max", value: "--", color: .gray)
            ]
        }
        let values = points.map(\.value)
        let avg = values.reduce(0, +) / Double(values.count)
        let out = points.filter(\.isOutOfRange).count
        let last = points.last?.value ?? 0
        let maxValue = values.max() ?? 0
        return [
            AnalyticsKPI(title: "Ultima", value: formatTemp(last), color: .primary),
            AnalyticsKPI(title: "Media", value: formatTemp(avg), color: .yellow),
            AnalyticsKPI(title: "Fuori range", value: "\(out)", color: out > 0 ? .red : .green),
            AnalyticsKPI(title: "Max", value: formatTemp(maxValue), color: .red)
        ]
    }

    // MARK: - Pulizia

    func cleaningStackedPoints(
        restaurantId: UUID,
        records: [CleaningRecord],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsBarSeriesPoint] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && $0.updatedAt >= start && $0.completed }
        return dayBuckets(period: period, now: now).flatMap { bucket -> [AnalyticsBarSeriesPoint] in
            let day = recordsInBucket(scoped, date: \.updatedAt, bucket: bucket)
            let pulito = Double(day.filter { $0.outcome == .pulito }.count)
            let nonPulito = Double(day.filter { $0.outcome == .nonPulito }.count)
            let na = Double(day.filter { $0.outcome == .nonApplicabile }.count)
            return [
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Pulito", value: pulito),
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Non pulito", value: nonPulito),
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "N/A", value: na)
            ]
        }
    }

    func cleaningKPIs(records: [CleaningRecord], criticalities: [CleaningCriticality], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsKPI] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && $0.updatedAt >= start && $0.completed }
        let pulito = scoped.filter { $0.outcome == .pulito }.count
        let total = scoped.count
        let pct = total == 0 ? 0 : Int((Double(pulito) / Double(total) * 100).rounded())
        let openCrit = criticalities.filter { $0.restaurantId == restaurantId && !$0.isResolved }.count
        return [
            AnalyticsKPI(title: "Completate", value: "\(total)", color: .primary),
            AnalyticsKPI(title: "Pulizie OK", value: "\(pct)%", color: pct >= 90 ? .green : .yellow),
            AnalyticsKPI(title: "Non pulito", value: "\(scoped.filter { $0.outcome == .nonPulito }.count)", color: .red),
            AnalyticsKPI(title: "Criticità aperte", value: "\(openCrit)", color: openCrit > 0 ? .red : .gray)
        ]
    }

    // MARK: - Abbattimento

    func blastChillingDailyPoints(
        restaurantId: UUID,
        records: [BlastChillingRecord],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsDailyPoint] {
        let start = period.startDate(now: now)
        let scoped = records.filter {
            $0.restaurantId == restaurantId && ($0.endedAt ?? $0.startedAt) >= start && $0.status != .inCorso
        }
        return dayBuckets(period: period, now: now).map { bucket in
            let count = recordsInBucket(scoped, date: { $0.endedAt ?? $0.startedAt }, bucket: bucket).count
            return AnalyticsDailyPoint(dayStart: bucket.start, label: bucket.label, value: Double(count))
        }
    }

    func blastChillingSlices(records: [BlastChillingRecord], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsSlicePoint] {
        let start = period.startDate(now: now)
        let scoped = records.filter {
            $0.restaurantId == restaurantId && ($0.endedAt ?? $0.startedAt) >= start && $0.status != .inCorso
        }
        let conforme = Double(scoped.filter { $0.status == .conforme }.count)
        let nonConf = Double(scoped.filter { $0.status == .nonConforme }.count)
        let annullato = Double(scoped.filter { $0.status == .annullato }.count)
        return [
            AnalyticsSlicePoint(label: "Conforme", value: conforme, color: .green),
            AnalyticsSlicePoint(label: "Non conforme", value: nonConf, color: .red),
            AnalyticsSlicePoint(label: "Annullato", value: annullato, color: .gray)
        ].filter { $0.value > 0 }
    }

    func blastChillingKPIs(records: [BlastChillingRecord], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsKPI] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && ($0.endedAt ?? $0.startedAt) >= start }
        let completed = scoped.filter { $0.status != .inCorso }
        let conforme = completed.filter { $0.status == .conforme }.count
        let inCorso = scoped.filter { $0.status == .inCorso }.count
        return [
            AnalyticsKPI(title: "Completati", value: "\(completed.count)", color: .primary),
            AnalyticsKPI(title: "Conformi", value: "\(conforme)", color: .green),
            AnalyticsKPI(title: "In corso", value: "\(inCorso)", color: .blue),
            AnalyticsKPI(title: "Non conformi", value: "\(completed.filter { $0.status == .nonConforme }.count)", color: .red)
        ]
    }

    // MARK: - Decongelamento

    func defrostDailyPoints(
        restaurantId: UUID,
        records: [DefrostRecord],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsDailyPoint] {
        let start = period.startDate(now: now)
        let scoped = records.filter {
            $0.restaurantId == restaurantId && ($0.endAt ?? $0.startAt) >= start && $0.endAt != nil
        }
        return dayBuckets(period: period, now: now).map { bucket in
            let count = recordsInBucket(scoped, date: { $0.endAt ?? $0.startAt }, bucket: bucket).count
            return AnalyticsDailyPoint(dayStart: bucket.start, label: bucket.label, value: Double(count))
        }
    }

    func defrostSlices(records: [DefrostRecord], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsSlicePoint] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && ($0.endAt ?? $0.startAt) >= start && $0.endAt != nil }
        let conforme = Double(scoped.filter { $0.outcome == .conforme }.count)
        let nonConf = Double(scoped.filter { $0.outcome == .nonConforme }.count)
        let cancelled = Double(scoped.filter { DefrostStatus(rawValue: $0.statusRaw) == .cancelled }.count)
        return [
            AnalyticsSlicePoint(label: "Conforme", value: conforme, color: .green),
            AnalyticsSlicePoint(label: "Non conforme", value: nonConf, color: .red),
            AnalyticsSlicePoint(label: "Annullato", value: cancelled, color: .gray)
        ].filter { $0.value > 0 }
    }

    func defrostKPIs(records: [DefrostRecord], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsKPI] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId }
        let active = scoped.filter(\.isActive).count
        let completed = scoped.filter { ($0.endAt ?? .distantPast) >= start && $0.endAt != nil }
        return [
            AnalyticsKPI(title: "In corso", value: "\(active)", color: .blue),
            AnalyticsKPI(title: "Completati", value: "\(completed.count)", color: .primary),
            AnalyticsKPI(title: "Conformi", value: "\(completed.filter { $0.outcome == .conforme }.count)", color: .green),
            AnalyticsKPI(title: "Non conformi", value: "\(completed.filter { $0.outcome == .nonConforme }.count)", color: .red)
        ]
    }

    // MARK: - Olio

    func oilPolarLinePoints(
        restaurantId: UUID,
        records: [OilControlRecord],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsLinePoint] {
        let start = period.startDate(now: now)
        let settings = SettingsStorageService.shared.haccp
        return records
            .filter { $0.restaurantId == restaurantId && $0.checkedAt >= start }
            .compactMap { record -> AnalyticsLinePoint? in
                guard let value = record.effectivePolarCompoundsValue else { return nil }
                let critical = value >= settings.oilPolarMaximumLimit
                return AnalyticsLinePoint(timestamp: record.checkedAt, value: value, isHighlighted: critical)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func oilStatusStackedPoints(
        restaurantId: UUID,
        records: [OilControlRecord],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsBarSeriesPoint] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && $0.checkedAt >= start }
        return dayBuckets(period: period, now: now).flatMap { bucket -> [AnalyticsBarSeriesPoint] in
            let day = recordsInBucket(scoped, date: \.checkedAt, bucket: bucket)
            let conforme = Double(day.filter { $0.oilStatus == .conforme }.count)
            let monitor = Double(day.filter { $0.oilStatus == .daMonitorare }.count)
            let critical = Double(day.filter { $0.oilStatus == .daSostituire || $0.oilStatus == .nonConforme }.count)
            return [
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Conforme", value: conforme),
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Da monitorare", value: monitor),
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Non conforme", value: critical)
            ]
        }
    }

    func oilKPIs(records: [OilControlRecord], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsKPI] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && $0.checkedAt >= start }
        let polarValues = scoped.compactMap(\.effectivePolarCompoundsValue)
        let avg = polarValues.isEmpty ? nil : polarValues.reduce(0, +) / Double(polarValues.count)
        let last = polarValues.last
        let critical = scoped.filter { $0.oilStatus.isCritical }.count
        return [
            AnalyticsKPI(title: "Controlli", value: "\(scoped.count)", color: .primary),
            AnalyticsKPI(title: "Ultimo TPM %", value: last.map { String(format: "%.1f", $0) } ?? "--", color: .yellow),
            AnalyticsKPI(title: "Media TPM %", value: avg.map { String(format: "%.1f", $0) } ?? "--", color: .orange),
            AnalyticsKPI(title: "Critici", value: "\(critical)", color: critical > 0 ? .red : .green)
        ]
    }

    // MARK: - Ricezione merci

    func goodsReceivingStackedPoints(
        restaurantId: UUID,
        records: [GoodsReceivingRecord],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsBarSeriesPoint] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && $0.receivedAt >= start }
        return dayBuckets(period: period, now: now).flatMap { bucket -> [AnalyticsBarSeriesPoint] in
            let day = recordsInBucket(scoped, date: \.receivedAt, bucket: bucket)
            let conforme = Double(day.filter { $0.status == .conforme || $0.status == .acceptedWithNotes }.count)
            let nonConf = Double(day.filter { $0.status == .nonConforme || $0.status == .rejected }.count)
            return [
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Conforme", value: conforme),
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Non conforme", value: nonConf)
            ]
        }
    }

    func goodsReceivingKPIs(records: [GoodsReceivingRecord], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsKPI] {
        let start = period.startDate(now: now)
        let scoped = records.filter { $0.restaurantId == restaurantId && $0.receivedAt >= start }
        let conforme = scoped.filter { $0.status == .conforme || $0.status == .acceptedWithNotes }.count
        let pct = scoped.isEmpty ? 0 : Int((Double(conforme) / Double(scoped.count) * 100).rounded())
        let tempOut = scoped.filter { $0.temperatureStatus == .nonConforme }.count
        return [
            AnalyticsKPI(title: "Ricezioni", value: "\(scoped.count)", color: .primary),
            AnalyticsKPI(title: "Conformità", value: "\(pct)%", color: pct >= 90 ? .green : .yellow),
            AnalyticsKPI(title: "Temp. fuori range", value: "\(tempOut)", color: tempOut > 0 ? .red : .green),
            AnalyticsKPI(title: "Rifiutate", value: "\(scoped.filter { $0.status == .rejected }.count)", color: .red)
        ]
    }

    // MARK: - Tracciabilità / scadenze

    func traceabilityStatusSlices(records: [TraceabilityRecord], restaurantId: UUID) -> [AnalyticsSlicePoint] {
        let scoped = records.filter { $0.restaurantId == restaurantId && !$0.isArchived }
        return ProductStatus.allCases.compactMap { status -> AnalyticsSlicePoint? in
            let count = Double(scoped.filter { $0.productStatus == status }.count)
            guard count > 0 else { return nil }
            let color: Color = {
                switch status {
                case .available: return .green
                case .used: return .blue
                case .expired, .rejected: return .red
                }
            }()
            return AnalyticsSlicePoint(label: status.label, value: count, color: color)
        }
    }

    func expiryUpcomingDailyPoints(
        records: [TraceabilityRecord],
        restaurantId: UUID,
        now: Date = Date()
    ) -> [AnalyticsDailyPoint] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let scoped = records.filter {
            $0.restaurantId == restaurantId
                && !$0.isArchived
                && $0.productStatus == .available
                && $0.expiryDate != nil
        }
        return (0..<7).compactMap { offset -> AnalyticsDailyPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let count = scoped.filter {
                guard let expiry = $0.expiryDate else { return false }
                return expiry >= day && expiry < dayEnd
            }.count
            let label = offset == 0 ? "Oggi" : day.formatted(.dateTime.weekday(.abbreviated)).capitalized
            return AnalyticsDailyPoint(dayStart: day, label: label, value: Double(count))
        }
    }

    func traceabilityKPIs(records: [TraceabilityRecord], restaurantId: UUID, now: Date = Date()) -> [AnalyticsKPI] {
        let scoped = records.filter { $0.restaurantId == restaurantId && !$0.isArchived }
        let thresholdDays = SettingsStorageService.shared.haccp.productExpiryThreshold
        let expiringSoon = scoped.filter {
            ProductExpiryEvaluator.isMonitorableExpiring($0, thresholdDays: thresholdDays, now: now)
        }.count
        let expiredCount = scoped.filter {
            ProductExpiryEvaluator.effectiveDisplayStatus($0, expiryDate: $0.expiryDate, now: now) == .expired
        }.count
        return [
            AnalyticsKPI(title: "Disponibili", value: "\(scoped.filter { $0.productStatus == .available }.count)", color: .green),
            AnalyticsKPI(title: "Scadenza ≤\(thresholdDays) gg", value: "\(expiringSoon)", color: expiringSoon > 0 ? .orange : .gray),
            AnalyticsKPI(title: "Scaduti", value: "\(expiredCount)", color: .red),
            AnalyticsKPI(title: "Respinti", value: "\(scoped.filter { $0.productStatus == .rejected }.count)", color: .red)
        ]
    }

    // MARK: - Etichette

    func labelsDailyPoints(
        restaurantId: UUID,
        labels: [ProductionLabelRecord],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsDailyPoint] {
        let start = period.startDate(now: now)
        let scoped = labels.filter { $0.restaurantId == restaurantId && $0.createdAt >= start }
        return dayBuckets(period: period, now: now).map { bucket in
            let count = recordsInBucket(scoped, date: \.createdAt, bucket: bucket).count
            return AnalyticsDailyPoint(dayStart: bucket.start, label: bucket.label, value: Double(count))
        }
    }

    func labelsKPIs(labels: [ProductionLabelRecord], restaurantId: UUID, period: AnalyticsPeriod, now: Date = Date()) -> [AnalyticsKPI] {
        let start = period.startDate(now: now)
        let scoped = labels.filter { $0.restaurantId == restaurantId && $0.createdAt >= start }
        let reprints = scoped.map(\.reprintCount).reduce(0, +)
        return [
            AnalyticsKPI(title: "Create", value: "\(scoped.count)", color: .primary),
            AnalyticsKPI(title: "Ristampe", value: "\(reprints)", color: .blue),
            AnalyticsKPI(title: "Attive", value: "\(scoped.filter { $0.labelStatus == .active }.count)", color: .green),
            AnalyticsKPI(title: "Da abbattimento", value: "\(scoped.filter { $0.sourceModule == .blastChilling }.count)", color: .cyan)
        ]
    }

    // MARK: - Programmazione

    func schedulingStackedPoints(
        restaurantId: UUID,
        tasks: [ScheduledTask],
        period: AnalyticsPeriod,
        now: Date = Date()
    ) -> [AnalyticsBarSeriesPoint] {
        let start = period.startDate(now: now)
        let scoped = tasks.filter { $0.restaurantId == restaurantId && ($0.dueAt ?? $0.createdAt) >= start }
        return dayBuckets(period: period, now: now).flatMap { bucket -> [AnalyticsBarSeriesPoint] in
            let day = scoped.filter {
                let anchor = $0.dueAt ?? $0.createdAt
                return anchor >= bucket.start && anchor < bucket.end
            }
            let done = Double(day.filter(\.isCompleted).count)
            let pending = Double(day.filter { !$0.isCompleted }.count)
            return [
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Completate", value: done),
                AnalyticsBarSeriesPoint(dayLabel: bucket.label, series: "Da fare", value: pending)
            ]
        }
    }

    func schedulingKPIs(tasks: [ScheduledTask], restaurantId: UUID, now: Date = Date()) -> [AnalyticsKPI] {
        let scoped = tasks.filter { $0.restaurantId == restaurantId }
        let overdue = scoped.filter { !$0.isCompleted && ($0.dueAt ?? .distantFuture) < now }.count
        let pending = scoped.filter { !$0.isCompleted }.count
        let done = scoped.filter(\.isCompleted).count
        return [
            AnalyticsKPI(title: "Da fare", value: "\(pending)", color: pending > 0 ? .orange : .gray),
            AnalyticsKPI(title: "In ritardo", value: "\(overdue)", color: overdue > 0 ? .red : .green),
            AnalyticsKPI(title: "Completate", value: "\(done)", color: .green),
            AnalyticsKPI(title: "Totale", value: "\(scoped.count)", color: .primary)
        ]
    }

    // MARK: - Helpers

    private func formatTemp(_ value: Double) -> String {
        String(format: "%.1f °C", value)
    }
}
