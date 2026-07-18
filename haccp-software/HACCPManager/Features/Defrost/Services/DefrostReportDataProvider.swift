//
//  DefrostReportDataProvider.swift
//  Predisposizione report documenti HACCP.
//

import Foundation

struct DefrostReportRow {
    let prodotto: String
    let lotto: String
    let metodo: String
    let inizio: Date
    let finePrevista: Date?
    let fine: Date?
    let durata: String
    let temperaturaIniziale: Double?
    let temperaturaFinale: Double?
    let stato: String
    let esito: String
    let operatore: String
    let note: String
    let azioneCorrettiva: String
}

struct DefrostReportDataProvider {
    func rows(
        restaurantId: UUID,
        records: [DefrostRecord],
        from startDate: Date,
        to endDate: Date
    ) -> [DefrostReportRow] {
        records
            .filter {
                $0.restaurantId == restaurantId &&
                $0.startAt >= startDate &&
                $0.startAt <= endDate
            }
            .sorted { $0.startAt < $1.startAt }
            .map {
                DefrostReportRow(
                    prodotto: $0.productName,
                    lotto: $0.lotNumber ?? "—",
                    metodo: $0.method,
                    inizio: $0.startAt,
                    finePrevista: $0.expectedEndAt,
                    fine: $0.endAt,
                    durata: $0.durationText,
                    temperaturaIniziale: $0.initialTemperature,
                    temperaturaFinale: $0.finalTemperature,
                    stato: $0.defrostStatus.label,
                    esito: $0.outcome?.label ?? "—",
                    operatore: $0.createdByNameSnapshot,
                    note: $0.notes ?? "",
                    azioneCorrettiva: $0.correctiveAction ?? ""
                )
            }
    }
}
