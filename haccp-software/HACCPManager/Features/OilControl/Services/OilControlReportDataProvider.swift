import Foundation

struct OilControlReportRow {
    let checkedAt: Date
    let oilPointName: String
    let status: String
    let polarCompoundsValue: String
    let temperature: String
    let actionTaken: String
    let notes: String
    let operatorName: String
}

struct OilControlReportDataProvider {
    func rows(
        records: [OilControlRecord],
        restaurantId: UUID,
        startDate: Date,
        endDate: Date
    ) -> [OilControlReportRow] {
        records
            .filter {
                $0.restaurantId == restaurantId &&
                $0.checkedAt >= startDate &&
                $0.checkedAt <= endDate
            }
            .sorted { $0.checkedAt < $1.checkedAt }
            .map {
                OilControlReportRow(
                    checkedAt: $0.checkedAt,
                    oilPointName: $0.oilPointNameSnapshot,
                    status: $0.oilStatus.label,
                    polarCompoundsValue: $0.effectivePolarCompoundsValue.map { String(format: "%.1f%%", $0) } ?? "—",
                    temperature: $0.temperature.map { String(format: "%.1f °C", $0) } ?? "—",
                    actionTaken: $0.oilAction.label,
                    notes: $0.notes ?? "—",
                    operatorName: $0.createdByNameSnapshot
                )
            }
    }
}
