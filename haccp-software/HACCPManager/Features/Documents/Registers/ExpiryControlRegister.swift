import Foundation

/// Monitoraggio scadenze produzioni finite (post-abbattimento / preparazione).
enum ExpiryControlRegister {
    struct Row {
        let product: String
        let lot: String
        let expiry: String
        let status: String
        let source: String
        let registeredAt: String
        let operatorName: String
    }

    static func productionRows(
        in interval: DateInterval,
        records: [TraceabilityRecord],
        df: DateFormatter
    ) -> [Row] {
        records
            .filter { TraceabilityRecordSupport.isProductionExpiryRecord($0) }
            .filter { record in
                interval.contains(record.receivedAt)
                    || (record.expiryDate.map { interval.contains($0) } ?? false)
            }
            .sorted { ($0.expiryDate ?? $0.receivedAt) > ($1.expiryDate ?? $1.receivedAt) }
            .map { record in
                Row(
                    product: record.productName,
                    lot: record.lotCode.isEmpty ? "—" : record.lotCode,
                    expiry: record.expiryDate.map { df.string(from: $0) } ?? "—",
                    status: record.productStatus.label,
                    source: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                    registeredAt: df.string(from: record.receivedAt),
                    operatorName: record.createdByNameSnapshot
                )
            }
    }
}
