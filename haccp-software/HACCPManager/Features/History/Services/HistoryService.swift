import Foundation

struct HistoryService {
    func buildEntries(
        restaurantId: UUID,
        temperatureRecords: [TemperatureRecord],
        fridgeRecords: [FridgeCheckRecord],
        checklistRuns: [ChecklistRun],
        checklistItemResults: [ChecklistItemResult],
        cleaningRecords: [CleaningRecord],
        defrostRecords: [DefrostRecord],
        blastRecords: [BlastChillingRecord],
        labelRecords: [ProductionLabelRecord],
        goodsRecords: [GoodsReceipt],
        traceabilityRecords: [TraceabilityRecord],
        traceabilityLinks: [TraceabilityLink],
        traceabilityLogs: [TraceabilityLog],
        lottoProductionLinks: [LottoFotoProductionLink],
        lottoFotos: [LottoFoto],
        productions: [Production],
        oilRecords: [OilControlRecord]
    ) -> [HistoryEntry] {
        let temperature = TemperatureHistoryProvider().entries(records: temperatureRecords, legacyRecords: fridgeRecords, restaurantId: restaurantId)
        let checklist = ChecklistHistoryProvider().entries(
            runs: checklistRuns,
            itemResults: checklistItemResults,
            restaurantId: restaurantId
        )
        let cleaning = CleaningHistoryProvider().entries(from: cleaningRecords, restaurantId: restaurantId)
        let defrost = defrostRecords
            .filter { $0.restaurantId == restaurantId && $0.endAt != nil }
            .map {
                HistoryEntry(
                    id: "defrost-\($0.id)",
                    module: .defrost,
                    title: $0.productName,
                    category: $0.method,
                    status: $0.historyStatusLabel,
                    operatorName: $0.createdByNameSnapshot,
                    date: $0.historyAnchorDate,
                    details: [
                        .init(label: "Prodotto", value: $0.productName),
                        .init(label: "Lotto", value: $0.lotNumber ?? "—"),
                        .init(label: "Inizio", value: $0.startAt.formatted(date: .abbreviated, time: .shortened)),
                        .init(label: "Fine", value: $0.endAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"),
                        .init(label: "Durata", value: $0.durationText),
                        .init(label: "Metodo", value: $0.method),
                        .init(label: "Temperatura iniziale", value: $0.initialTemperature.map { String(format: "%.1f °C", $0) } ?? "—"),
                        .init(label: "Temperatura finale", value: $0.finalTemperature.map { String(format: "%.1f °C", $0) } ?? "—"),
                        .init(label: "Esito", value: $0.outcome?.label ?? ($0.endAt == nil ? "In corso" : "—")),
                        .init(label: "Azione correttiva", value: $0.correctiveAction ?? "—"),
                        .init(label: "Note", value: $0.notes ?? "—")
                    ],
                    hasCriticality: $0.statusRaw == DefrostStatus.completedWithCriticality.rawValue
                        || $0.outcome == .nonConforme
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
                    category: $0.sourceModule.label,
                    status: $0.labelStatus.label,
                    operatorName: $0.createdByNameSnapshot,
                    date: $0.createdAt,
                    details: [
                        .init(label: "Prodotto", value: $0.productName),
                        .init(label: "Lotto", value: $0.lotCode ?? "—"),
                        .init(label: "Fornitore", value: $0.supplier ?? "—"),
                        .init(label: "Data produzione", value: $0.productionDate.formatted(date: .abbreviated, time: .omitted)),
                        .init(label: "Scadenza", value: $0.expiryDate.formatted(date: .abbreviated, time: .omitted)),
                        .init(label: "Allergeni", value: $0.allergens ?? "—"),
                        .init(label: "Conservazione", value: $0.storageInstructions ?? "—"),
                        .init(label: "Origine", value: $0.sourceModule.label)
                    ],
                    hasCriticality: $0.expiryState == .expired
                )
            }
        let goods = GoodsReceivingHistoryProvider().entries(from: goodsRecords, restaurantId: restaurantId)
        let traceability = TraceabilityHistoryProvider().entries(
            records: traceabilityRecords,
            productions: productions,
            links: traceabilityLinks,
            lottoProductionLinks: lottoProductionLinks,
            lottoFotos: lottoFotos,
            restaurantId: restaurantId
        )
        let traceabilityTimeline = TraceabilityHistoryProvider().logEntries(
            logs: traceabilityLogs,
            records: traceabilityRecords,
            productions: productions,
            restaurantId: restaurantId
        )
        let expiry = ExpiryHistoryProvider().entries(
            traceabilityRecords: traceabilityRecords,
            traceabilityLogs: traceabilityLogs,
            lottoFotos: lottoFotos,
            restaurantId: restaurantId
        )

        let oil = OilControlHistoryProvider().entries(from: oilRecords, restaurantId: restaurantId)

        return (temperature + checklist + cleaning + defrost + blast + labels + goods + traceability + traceabilityTimeline + expiry + oil)
            .sorted(by: { $0.date > $1.date })
    }
}
