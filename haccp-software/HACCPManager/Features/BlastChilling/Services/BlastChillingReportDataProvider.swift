import Foundation

struct BlastChillingReportRow {
    let produzione: String
    let categoria: String
    let inizio: Date
    let fine: Date?
    let temperaturaIniziale: Double
    let temperaturaFinale: Double?
    let temperaturaTarget: Double
    let stato: String
    let operatore: String
    let note: String
    let azioneCorrettiva: String
}

struct BlastChillingReportDataProvider {
    func rows(
        restaurantId: UUID,
        records: [BlastChillingRecord],
        from startDate: Date,
        to endDate: Date
    ) -> [BlastChillingReportRow] {
        records
            .filter {
                $0.restaurantId == restaurantId &&
                $0.startedAt >= startDate &&
                $0.startedAt <= endDate
            }
            .sorted { $0.startedAt < $1.startedAt }
            .map {
                BlastChillingReportRow(
                    produzione: $0.productionNameSnapshot,
                    categoria: $0.productionCategorySnapshot,
                    inizio: $0.startedAt,
                    fine: $0.endedAt,
                    temperaturaIniziale: $0.initialTemperature,
                    temperaturaFinale: $0.finalTemperature,
                    temperaturaTarget: $0.targetTemperature,
                    stato: $0.status.label,
                    operatore: $0.createdByNameSnapshot,
                    note: $0.notes ?? "",
                    azioneCorrettiva: $0.correctiveAction ?? ""
                )
            }
    }
}
