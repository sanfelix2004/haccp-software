import Foundation

/// Aggregazione audit per report ufficiali (moduli con log persistiti).
enum HACCPDocumentAuditLogBuilder {
    struct Row {
        let userName: String
        let module: String
        let timestamp: String
        let action: String
        let entityRef: String
    }

    static func rows(
        restaurantId: UUID,
        interval: DateInterval,
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        traceabilityLogs: [TraceabilityLog],
        traceabilityRecordIds: Set<UUID>,
        df: DateFormatter
    ) -> [Row] {
        var rows: [Row] = []

        for log in checklistLogs where log.restaurantId == restaurantId && interval.contains(log.timestamp) {
            let ref = String(log.entityId.uuidString.prefix(8)).uppercased() + (log.details.map { " — \($0)" } ?? "")
            rows.append(Row(
                userName: log.userName,
                module: log.module,
                timestamp: df.string(from: log.timestamp),
                action: log.action,
                entityRef: ref
            ))
        }

        for log in temperatureLogs where log.restaurantId == restaurantId && interval.contains(log.createdAt) {
            rows.append(Row(
                userName: log.userName,
                module: "Temperatura",
                timestamp: df.string(from: log.createdAt),
                action: log.action,
                entityRef: "\(log.deviceName)\(log.details.map { " — \($0)" } ?? "")"
            ))
        }

        for log in traceabilityLogs where traceabilityRecordIds.contains(log.receivedItemId) && interval.contains(log.timestamp) {
            let actionLabel: String = switch log.actionType {
            case .created: "Creazione record"
            case .linkedToProduction: "Collegamento a produzione"
            case .expired: "Scadenza"
            case .rejected: "Respinto"
            case .nonCompliance: "Non conformità"
            }
            rows.append(Row(
                userName: log.operatorName,
                module: "Tracciabilità",
                timestamp: df.string(from: log.timestamp),
                action: actionLabel,
                entityRef: String(log.receivedItemId.uuidString.prefix(8)).uppercased()
            ))
        }

        return rows.sorted { $0.timestamp > $1.timestamp }
    }
}
