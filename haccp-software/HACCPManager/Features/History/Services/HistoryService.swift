import Foundation

struct HistoryService {
    func buildEntries(
        restaurantId: UUID,
        temperatureRecords: [TemperatureRecord],
        fridgeRecords: [FridgeCheckRecord],
        checklistRuns: [ChecklistRun],
        checklistItemResults: [ChecklistItemResult],
        checklistAuditLogs: [ChecklistAuditLog],
        cleaningRecords: [CleaningRecord],
        defrostRecords: [DefrostRecord],
        blastRecords: [BlastChillingRecord],
        labelRecords: [ProductionLabelRecord],
        goodsRecords: [GoodsReceipt],
        traceabilityRecords: [TraceabilityRecord],
        traceabilityLogs: [TraceabilityLog],
        scheduledTasks: [ScheduledTask],
        oilRecords: [OilControlRecord]
    ) -> [HistoryEntry] {
        let temperature = TemperatureHistoryProvider().entries(records: temperatureRecords, legacyRecords: fridgeRecords, restaurantId: restaurantId)
        let checklist = checklistRuns.filter { $0.restaurantId == restaurantId }.map {
            HistoryEntry(
                id: "checklist-run-\($0.id)",
                module: .checklist,
                title: $0.templateTitleSnapshot,
                category: $0.status.label,
                status: $0.status.label,
                operatorName: $0.completedByNameSnapshot ?? "-",
                date: $0.completedAt ?? $0.startedAt,
                details: [
                    .init(label: "Checklist", value: $0.templateTitleSnapshot),
                    .init(label: "Stato", value: $0.status.label),
                    .init(label: "Avvio", value: ($0.startedAt).formatted(date: .abbreviated, time: .shortened)),
                    .init(label: "Completamento", value: $0.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"),
                    .init(label: "Note", value: $0.notes ?? "—")
                ],
                hasCriticality: $0.status == .failed
            )
        }
        let checklistRunsById = Dictionary(uniqueKeysWithValues: checklistRuns.map { ($0.id, $0) })
        let checklistItems = checklistItemResults
            .compactMap { item -> HistoryEntry? in
                guard
                    let run = checklistRunsById[item.checklistRunId],
                    run.restaurantId == restaurantId,
                    item.result != .pending,
                    let completedAt = item.completedAt
                else { return nil }
                return HistoryEntry(
                    id: "checklist-item-\(item.id)",
                    module: .checklist,
                    title: item.titleSnapshot,
                    category: item.result.label,
                    status: item.result.label,
                    operatorName: run.completedByNameSnapshot ?? "-",
                    date: completedAt,
                    details: [
                        .init(label: "Checklist", value: run.templateTitleSnapshot),
                        .init(label: "Risultato", value: item.result.label),
                        .init(label: "Nota", value: item.note ?? "—")
                    ],
                    hasCriticality: item.result == .fail
                )
            }
        let checklistAudit = checklistAuditLogs
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    id: "checklist-audit-\($0.id)",
                    module: .checklist,
                    title: $0.action,
                    category: $0.module,
                    status: "Audit",
                    operatorName: $0.userName,
                    date: $0.timestamp,
                    details: [
                        .init(label: "Dettagli", value: $0.details ?? "—"),
                        .init(label: "Entità", value: String($0.entityId.uuidString.prefix(8)).uppercased())
                    ],
                    hasCriticality: false
                )
            }
        let cleaning = CleaningHistoryProvider().entries(from: cleaningRecords, restaurantId: restaurantId)
        let defrost = defrostRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    id: "defrost-\($0.id)",
                    module: .defrost,
                    title: $0.productName,
                    category: $0.method,
                    status: $0.endAt == nil ? "In corso" : "Completato",
                    operatorName: $0.createdByNameSnapshot,
                    date: $0.startAt,
                    details: [
                        .init(label: "Prodotto/produzione", value: $0.productName),
                        .init(label: "Inizio", value: $0.startAt.formatted(date: .abbreviated, time: .shortened)),
                        .init(label: "Fine", value: $0.endAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"),
                        .init(label: "Metodo", value: $0.method),
                        .init(label: "Esito", value: $0.endAt == nil ? "In corso" : "Completato"),
                        .init(label: "Note", value: $0.notes ?? "—")
                    ],
                    hasCriticality: false
                )
            }
        let blast = BlastChillingHistoryProvider().entries(from: blastRecords, restaurantId: restaurantId)
        let labels = labelRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    id: "label-\($0.id)",
                    module: .productionLabels,
                    title: $0.productName,
                    category: "Etichetta",
                    status: "Creata",
                    operatorName: $0.createdByNameSnapshot,
                    date: $0.createdAt,
                    details: [
                        .init(label: "Prodotto", value: $0.productName),
                        .init(label: "Lotto", value: $0.lotCode ?? "—"),
                        .init(label: "Data produzione", value: $0.productionDate.formatted(date: .abbreviated, time: .omitted)),
                        .init(label: "Scadenza", value: $0.expiryDate.formatted(date: .abbreviated, time: .omitted)),
                        .init(label: "Anteprima", value: $0.previewText ?? "—")
                    ],
                    hasCriticality: false
                )
            }
        let goods = GoodsReceivingHistoryProvider().entries(from: goodsRecords, restaurantId: restaurantId)
        let traceability = TraceabilityHistoryProvider().entries(records: traceabilityRecords, logs: traceabilityLogs, restaurantId: restaurantId)
        let expiry = ExpiryHistoryProvider().entries(traceabilityRecords: traceabilityRecords, restaurantId: restaurantId)

        let scheduling = scheduledTasks
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    id: "schedule-\($0.id)",
                    module: .scheduling,
                    title: $0.title,
                    category: $0.isCompleted ? "Completata" : "Da svolgere",
                    status: $0.isCompleted ? "Completata" : "Da svolgere",
                    operatorName: $0.createdByNameSnapshot,
                    date: $0.dueAt ?? $0.createdAt,
                    details: [
                        .init(label: "Attività", value: $0.title),
                        .init(label: "Descrizione", value: $0.taskDescription),
                        .init(label: "Frequenza", value: $0.frequency.rawValue),
                        .init(label: "Scadenza", value: $0.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"),
                        .init(label: "Stato", value: $0.isCompleted ? "Completata" : "Da svolgere"),
                        .init(label: "Note", value: $0.notes ?? "—")
                    ],
                    hasCriticality: !$0.isCompleted && (($0.dueAt ?? .distantFuture) < Date())
                )
            }

        let oil = OilControlHistoryProvider().entries(from: oilRecords, restaurantId: restaurantId)

        return (temperature + checklist + checklistItems + checklistAudit + cleaning + defrost + blast + labels + goods + traceability + expiry + scheduling + oil)
            .sorted(by: { $0.date > $1.date })
    }
}
