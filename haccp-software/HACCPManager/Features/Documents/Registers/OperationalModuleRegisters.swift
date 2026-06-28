import Foundation

enum TemperatureRegister {
    struct Row {
        let device: String
        let measuredAt: String
        let value: String
        let range: String
        let status: String
        let operatorName: String
        let notes: String
    }

    static func rows(in interval: DateInterval, records: [TemperatureRecord], df: DateFormatter) -> [Row] {
        records
            .filter { interval.contains($0.measuredAt) }
            .sorted { $0.measuredAt > $1.measuredAt }
            .map { r in
                Row(
                    device: r.deviceName,
                    measuredAt: df.string(from: r.measuredAt),
                    value: String(format: "%.1f °C", r.value),
                    range: String(format: "%.1f … %.1f °C", r.minAllowed, r.maxAllowed),
                    status: r.status.label,
                    operatorName: r.measuredByName,
                    notes: (r.notes ?? "").isEmpty ? "—" : (r.notes ?? "")
                )
            }
    }
}

enum CleaningRegister {
    struct Row {
        let area: String
        let task: String
        let frequency: String
        let period: String
        let outcome: String
        let operatorName: String
        let notes: String
        let source: String
    }

    static func rows(in interval: DateInterval, records: [CleaningRecord], df: DateFormatter) -> [Row] {
        unifiedRows(
            in: interval,
            records: records,
            runs: [],
            itemResults: [],
            templates: [],
            df: df
        )
    }

    /// Registro sanificazione unificato: task pulizie + checklist procedurali (esclude bridge già coperti dai record pulizia).
    static func unifiedRows(
        in interval: DateInterval,
        records: [CleaningRecord],
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        templates: [ChecklistTemplate],
        df: DateFormatter
    ) -> [Row] {
        var dated: [(Date, Row)] = []

        for record in records where interval.contains(record.updatedAt) || interval.contains(record.periodStart) {
            let period = "\(df.string(from: record.periodStart)) → \(df.string(from: record.periodEnd))"
            dated.append((
                record.updatedAt,
                Row(
                    area: record.areaName,
                    task: record.taskName,
                    frequency: record.frequency.label,
                    period: period,
                    outcome: record.outcome.label,
                    operatorName: record.updatedByNameSnapshot,
                    notes: combinedNotes(record.notes, record.correctiveAction),
                    source: "Pulizie"
                )
            ))
        }

        let templateById = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        let resultsByRun = Dictionary(grouping: itemResults, by: \.checklistRunId)
        let bridgeTemplateIds = Set(templates.filter(\.isCleaningBridge).map(\.id))

        for run in runs {
            guard let template = templateById[run.templateId] else { continue }
            guard !bridgeTemplateIds.contains(template.id) else { continue }
            guard template.category == .cleaning else { continue }
            let anchor = run.completedAt ?? run.startedAt
            guard interval.contains(anchor) || interval.contains(run.startedAt) else { continue }

            let scoped = resultsByRun[run.id] ?? []
            let fails = scoped.filter { $0.result == .fail }.map(\.titleSnapshot).joined(separator: "; ")
            let itemNotes = scoped.compactMap(\.note).filter { !$0.isEmpty }.joined(separator: "; ")
            let periodEnd = run.completedAt.map { df.string(from: $0) } ?? "—"
            let period = "\(df.string(from: run.startedAt)) → \(periodEnd)"

            dated.append((
                anchor,
                Row(
                    area: template.areaTag ?? "—",
                    task: run.templateTitleSnapshot,
                    frequency: template.frequency.label,
                    period: period,
                    outcome: checklistOutcomeLabel(run: run, items: scoped),
                    operatorName: run.completedByNameSnapshot ?? "—",
                    notes: combinedNotes(run.notes, fails.isEmpty ? itemNotes : fails),
                    source: "Checklist"
                )
            ))
        }

        return dated.sorted { $0.0 > $1.0 }.map(\.1)
    }

    private static func checklistOutcomeLabel(run: ChecklistRun, items: [ChecklistItemResult]) -> String {
        if items.contains(where: { $0.result == .fail }) { return "Non conforme" }
        if run.status == .completed, items.allSatisfy({ $0.result == .pass || $0.result == .notApplicable }) {
            return "Conforme"
        }
        return run.status.label
    }

    private static func combinedNotes(_ notes: String?, _ extra: String?) -> String {
        let parts = [notes, extra]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

enum DefrostRegister {
    struct Row {
        let product: String
        let method: String
        let lot: String
        let startedAt: String
        let endedAt: String
        let duration: String
        let finalTemp: String
        let status: String
        let operatorName: String
        let notes: String
    }

    static func rows(in interval: DateInterval, records: [DefrostRecord], df: DateFormatter) -> [Row] {
        records
            .filter { interval.contains($0.startAt) }
            .sorted { $0.startAt > $1.startAt }
            .map { r in
                Row(
                    product: r.productName,
                    method: r.defrostMethod.label,
                    lot: r.lotNumber ?? "—",
                    startedAt: df.string(from: r.startAt),
                    endedAt: r.endAt.map { df.string(from: $0) } ?? "—",
                    duration: r.durationText,
                    finalTemp: r.finalTemperature.map { String(format: "%.1f °C", $0) } ?? "—",
                    status: r.defrostStatus.label,
                    operatorName: r.createdByNameSnapshot,
                    notes: [r.notes, r.correctiveAction].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "; ").ifEmpty("—")
                )
            }
    }
}

enum BlastChillingRegister {
    struct Row {
        let production: String
        let category: String
        let startedAt: String
        let endedAt: String
        let duration: String
        let initialTemp: String
        let finalTemp: String
        let targetTemp: String
        let status: String
        let operatorName: String
        let notes: String
    }

    static func rows(in interval: DateInterval, records: [BlastChillingRecord], df: DateFormatter) -> [Row] {
        records
            .filter { interval.contains($0.startedAt) }
            .sorted { $0.startedAt > $1.startedAt }
            .map { r in
                Row(
                    production: r.productionNameSnapshot,
                    category: r.productionCategorySnapshot,
                    startedAt: df.string(from: r.startedAt),
                    endedAt: r.endedAt.map { df.string(from: $0) } ?? "—",
                    duration: r.durationText,
                    initialTemp: String(format: "%.1f °C", r.initialTemperature),
                    finalTemp: r.finalTemperature.map { String(format: "%.1f °C", $0) } ?? "—",
                    targetTemp: String(format: "%.1f °C", r.targetTemperature),
                    status: r.status.label,
                    operatorName: r.createdByNameSnapshot,
                    notes: [r.notes, r.correctiveAction].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "; ").ifEmpty("—")
                )
            }
    }
}

enum OilControlRegister {
    struct Row {
        let point: String
        let checkedAt: String
        let status: String
        let polarCompounds: String
        let temperature: String
        let action: String
        let operatorName: String
        let notes: String
    }

    static func rows(in interval: DateInterval, records: [OilControlRecord], df: DateFormatter) -> [Row] {
        records
            .filter { interval.contains($0.checkedAt) }
            .sorted { $0.checkedAt > $1.checkedAt }
            .map { r in
                Row(
                    point: r.oilPointNameSnapshot,
                    checkedAt: df.string(from: r.checkedAt),
                    status: r.oilStatus.label,
                    polarCompounds: r.effectivePolarCompoundsValue.map { String(format: "%.1f%%", $0) } ?? "—",
                    temperature: r.temperature.map { String(format: "%.1f °C", $0) } ?? "—",
                    action: r.oilAction.label,
                    operatorName: r.createdByNameSnapshot,
                    notes: (r.notes ?? "").isEmpty ? "—" : (r.notes ?? "")
                )
            }
    }
}

enum ChecklistRegister {
    struct Row {
        let checklist: String
        let status: String
        let startedAt: String
        let completedAt: String
        let operatorName: String
        let progress: String
        let failedItems: String
        let notes: String
    }

    static func rows(
        in interval: DateInterval,
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        df: DateFormatter
    ) -> [Row] {
        let resultsByRun = Dictionary(grouping: itemResults, by: \.checklistRunId)
        return runs
            .filter { interval.contains($0.startedAt) }
            .sorted { $0.startedAt > $1.startedAt }
            .map { run in
                let scoped = resultsByRun[run.id] ?? []
                let fails = scoped.filter { $0.result == .fail }.map(\.titleSnapshot).joined(separator: "; ")
                return Row(
                    checklist: run.templateTitleSnapshot,
                    status: run.status.label,
                    startedAt: df.string(from: run.startedAt),
                    completedAt: run.completedAt.map { df.string(from: $0) } ?? "—",
                    operatorName: run.completedByNameSnapshot ?? "—",
                    progress: "\(Int(run.progressPercentage))%",
                    failedItems: fails.isEmpty ? "—" : fails,
                    notes: (run.notes ?? "").isEmpty ? "—" : (run.notes ?? "")
                )
            }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
