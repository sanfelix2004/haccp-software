import Foundation

struct HistoryEntry: Identifiable {
    let id = UUID()
    let module: String
    let title: String
    let category: String
    let operatorName: String
    let productOrDevice: String
    let date: Date
}

struct HistoryService {
    func buildEntries(
        restaurantId: UUID,
        temperatureRecords: [TemperatureRecord],
        checklistRuns: [ChecklistRun],
        cleaningRecords: [CleaningRecord],
        defrostRecords: [DefrostRecord],
        blastRecords: [BlastChillingRecord],
        labelRecords: [ProductionLabelRecord],
        goodsRecords: [GoodsReceipt],
        traceabilityRecords: [TraceabilityRecord],
        scheduledTasks: [ScheduledTask],
        oilRecords: [OilControlRecord]
    ) -> [HistoryEntry] {
        let temperature = temperatureRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Frigoriferi",
                    title: "Temperatura \(String(format: "%.1f", $0.value))°C",
                    category: $0.status.label,
                    operatorName: $0.measuredByName,
                    productOrDevice: $0.deviceName,
                    date: $0.measuredAt
                )
            }
        let checklist = checklistRuns
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Checklist",
                    title: $0.templateTitleSnapshot,
                    category: $0.status.label,
                    operatorName: $0.completedByNameSnapshot ?? "-",
                    productOrDevice: $0.templateTitleSnapshot,
                    date: $0.completedAt ?? $0.startedAt
                )
            }
        let cleaning = cleaningRecords
            .filter { $0.restaurantId == restaurantId && $0.outcome != .daFare }
            .map {
                HistoryEntry(
                    module: "Controllo pulizia",
                    title: "\($0.areaName) · \($0.taskName)",
                    category: $0.outcome.label,
                    operatorName: $0.updatedByNameSnapshot,
                    productOrDevice: $0.correctiveAction ?? $0.areaName,
                    date: $0.updatedAt
                )
            }
        let defrost = defrostRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Decongelamento",
                    title: $0.productName,
                    category: $0.method,
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.productName,
                    date: $0.createdAt
                )
            }
        let blast = blastRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Abbattimento",
                    title: $0.productionNameSnapshot,
                    category: $0.status.label,
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.productionCategorySnapshot,
                    date: $0.startedAt
                )
            }
        let labels = labelRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Etichette di produzione",
                    title: $0.productName,
                    category: "Etichetta",
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.productName,
                    date: $0.createdAt
                )
            }
        let goods = goodsRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Ricezione merci",
                    title: $0.productNameSnapshot,
                    category: $0.status.label,
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.productNameSnapshot,
                    date: $0.createdAt
                )
            }

        let traceability = traceabilityRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Tracciabilità",
                    title: $0.productName,
                    category: $0.productStatus.label,
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.lotCode,
                    date: $0.receivedAt
                )
            }

        let scheduling = scheduledTasks
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Programmazione",
                    title: $0.title,
                    category: $0.isCompleted ? "Completata" : "Da svolgere",
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.taskDescription,
                    date: $0.dueAt ?? $0.createdAt
                )
            }

        let oil = oilRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Controllo olio",
                    title: $0.oilState,
                    category: $0.actionTaken,
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.indexValue.map { String(format: "%.2f", $0) } ?? "—",
                    date: $0.checkedAt
                )
            }

        return (temperature + checklist + cleaning + defrost + blast + labels + goods + traceability + scheduling + oil)
            .sorted(by: { $0.date > $1.date })
    }
}
