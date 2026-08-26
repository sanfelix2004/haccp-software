import Foundation

/// Registro «Tracciabilità status»: produzioni finite e chiusure (disponibile / terminato / usato / scaduto / scartato).
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
        logs: [TraceabilityLog] = [],
        df: DateFormatter
    ) -> [Row] {
        let logsByRecord = Dictionary(grouping: logs, by: \.receivedItemId)

        return records
            .filter { !$0.isArchived && $0.isProductionBatchOutput }
            .filter { record in
                let recordLogs = logsByRecord[record.id] ?? []
                let status = TraceabilityLotOperationalStatus.present(
                    record: record,
                    logs: recordLogs
                ).label
                // Terminato: solo Storia — escluso dal PDF Documenti.
                if status == "Terminato" { return false }

                if interval.contains(record.receivedAt) { return true }
                if let expiry = record.expiryDate, interval.contains(expiry) { return true }
                // Chiusure nel periodo (Scartato / Scaduto / …) anche se create prima.
                return recordLogs.contains {
                    ($0.actionType == .withdrawn || $0.actionType == .archivedFromExpiryControl)
                        && interval.contains($0.timestamp)
                }
            }
            .sorted { ($0.expiryDate ?? $0.receivedAt) > ($1.expiryDate ?? $1.receivedAt) }
            .map { record in
                let status = TraceabilityLotOperationalStatus.present(
                    record: record,
                    logs: logsByRecord[record.id] ?? []
                ).label
                return Row(
                    product: record.productName,
                    lot: record.lotCode.isEmpty ? "—" : record.lotCode,
                    expiry: record.expiryDate.map { df.string(from: $0) } ?? "",
                    status: status,
                    source: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                    registeredAt: df.string(from: record.receivedAt),
                    operatorName: record.createdByNameSnapshot
                )
            }
    }
}
