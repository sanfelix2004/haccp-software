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
        goodsRecords: [GoodsReceivingRecord]
    ) -> [HistoryEntry] {
        let temperature = temperatureRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Frigoriferi",
                    title: "Temperatura \(String(format: "%.1f", $0.value))°C",
                    category: $0.status.rawValue,
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
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Controllo pulizia",
                    title: $0.areaName,
                    category: $0.completed ? "Completata" : "Da fare",
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.areaName,
                    date: $0.createdAt
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
                    title: $0.productName,
                    category: $0.outcome,
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.productName,
                    date: $0.createdAt
                )
            }
        let labels = labelRecords
            .filter { $0.restaurantId == restaurantId }
            .map {
                HistoryEntry(
                    module: "Etichette",
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
                    title: $0.productName,
                    category: $0.compliant ? "Conforme" : "Non conforme",
                    operatorName: $0.createdByNameSnapshot,
                    productOrDevice: $0.productName,
                    date: $0.createdAt
                )
            }

        return (temperature + checklist + cleaning + defrost + blast + labels + goods)
            .sorted(by: { $0.date > $1.date })
    }
}
