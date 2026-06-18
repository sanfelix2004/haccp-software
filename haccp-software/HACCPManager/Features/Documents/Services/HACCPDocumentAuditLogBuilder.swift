import Foundation

/// Eventi rilevanti per i report ufficiali (criticità, NC, anomalie — non log operativi completi).
enum HACCPDocumentAuditLogBuilder {
    struct Row {
        let timestamp: String
        let module: String
        let action: String
        let detail: String
        let operatorName: String
        let sortDate: Date
    }

    private static let maxRows = 60

    static func importantRows(
        restaurantId: UUID,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceabilityRecords: [TraceabilityRecord],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        traceabilityLogs: [TraceabilityLog],
        traceabilityRecordIds: Set<UUID>,
        df: DateFormatter
    ) -> [Row] {
        var rows: [Row] = []

        for receipt in receipts where receipt.restaurantId == restaurantId && interval.contains(receipt.receivedAt) {
            if receipt.status == .rejected {
                rows.append(Row(
                    timestamp: df.string(from: receipt.receivedAt),
                    module: "Ricezione merci",
                    action: "Merce respinta",
                    detail: "\(receipt.productNameSnapshot) · lotto \(receipt.lotNumber ?? "—")",
                    operatorName: receipt.createdByNameSnapshot,
                    sortDate: receipt.receivedAt
                ))
            } else if receipt.status == .nonConforme {
                rows.append(Row(
                    timestamp: df.string(from: receipt.receivedAt),
                    module: "Ricezione merci",
                    action: "Non conformità ricezione",
                    detail: "\(receipt.productNameSnapshot)\(receipt.notes.map { " — \($0)" } ?? "")",
                    operatorName: receipt.createdByNameSnapshot,
                    sortDate: receipt.receivedAt
                ))
            } else if receipt.temperatureStatus == .nonConforme {
                let temp = receipt.temperatureValue.map { String(format: "%.1f °C", $0) } ?? "—"
                rows.append(Row(
                    timestamp: df.string(from: receipt.receivedAt),
                    module: "Ricezione merci",
                    action: "Temperatura fuori range",
                    detail: "\(receipt.productNameSnapshot) · rilevata \(temp)",
                    operatorName: receipt.createdByNameSnapshot,
                    sortDate: receipt.receivedAt
                ))
            }

            let checklistIssues = receipt.checklistResults.filter { $0.value == .notOk }
            for issue in checklistIssues {
                let note = (issue.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let suffix = note.isEmpty ? "" : " — \(note)"
                rows.append(Row(
                    timestamp: df.string(from: receipt.receivedAt),
                    module: "Ricezione merci",
                    action: "Checklist NON OK",
                    detail: "\(receipt.productNameSnapshot): \(issue.item.rawValue)\(suffix)",
                    operatorName: receipt.createdByNameSnapshot,
                    sortDate: receipt.receivedAt
                ))
            }
        }

        for record in traceabilityRecords where traceabilityRecordIds.contains(record.id) && interval.contains(record.receivedAt) {
            if record.productStatus == .rejected {
                rows.append(Row(
                    timestamp: df.string(from: record.receivedAt),
                    module: "Tracciabilità",
                    action: "Prodotto respinto",
                    detail: "\(record.productName) · lotto \(record.lotCode.isEmpty ? "—" : record.lotCode)",
                    operatorName: record.createdByNameSnapshot,
                    sortDate: record.receivedAt
                ))
            } else if record.productStatus == .expired {
                rows.append(Row(
                    timestamp: df.string(from: record.receivedAt),
                    module: "Tracciabilità",
                    action: "Prodotto scaduto",
                    detail: record.productName,
                    operatorName: record.createdByNameSnapshot,
                    sortDate: record.receivedAt
                ))
            } else if record.isNonCompliant {
                let note = record.nonComplianceNote ?? ""
                rows.append(Row(
                    timestamp: df.string(from: record.receivedAt),
                    module: "Tracciabilità",
                    action: "Non conformità",
                    detail: "\(record.productName)\(note.isEmpty ? "" : " — \(note)")",
                    operatorName: record.createdByNameSnapshot,
                    sortDate: record.receivedAt
                ))
            }
        }

        for log in checklistLogs where log.restaurantId == restaurantId && interval.contains(log.timestamp) {
            guard isImportantChecklistAction(log.action) else { continue }
            rows.append(Row(
                timestamp: df.string(from: log.timestamp),
                module: "Checklist",
                action: humanChecklistAction(log.action),
                detail: log.details ?? "—",
                operatorName: log.userName,
                sortDate: log.timestamp
            ))
        }

        for log in temperatureLogs where log.restaurantId == restaurantId && interval.contains(log.createdAt) {
            guard isImportantTemperatureAction(log.action) else { continue }
            rows.append(Row(
                timestamp: df.string(from: log.createdAt),
                module: "Temperatura",
                action: humanTemperatureAction(log.action),
                detail: "\(log.deviceName)\(log.details.map { " — \($0)" } ?? "")",
                operatorName: log.userName,
                sortDate: log.createdAt
            ))
        }

        for log in traceabilityLogs where traceabilityRecordIds.contains(log.receivedItemId) && interval.contains(log.timestamp) {
            guard isImportantTraceabilityAction(log.actionType) else { continue }
            let productName = traceabilityRecords.first(where: { $0.id == log.receivedItemId })?.productName ?? "Voce tracciabilità"
            rows.append(Row(
                timestamp: df.string(from: log.timestamp),
                module: "Tracciabilità",
                action: traceabilityActionLabel(log.actionType),
                detail: log.detail ?? productName,
                operatorName: log.operatorName,
                sortDate: log.timestamp
            ))
        }

        return rows
            .sorted { $0.sortDate > $1.sortDate }
            .prefix(maxRows)
            .map { $0 }
    }

    private static func isImportantChecklistAction(_ action: String) -> Bool {
        action.contains("FAILED")
            || action.contains("ALERT_RESOLVED")
            || action.localizedCaseInsensitiveContains("criticit")
    }

    private static func isImportantTemperatureAction(_ action: String) -> Bool {
        action.contains("ALERT_RESOLVED")
            || action.localizedCaseInsensitiveContains("non")
            || action.localizedCaseInsensitiveContains("alert")
    }

    private static func isImportantTraceabilityAction(_ action: TraceabilityActionType) -> Bool {
        switch action {
        case .expired, .rejected, .nonCompliance, .withdrawn: return true
        case .created, .linkedToProduction: return false
        }
    }

    private static func humanChecklistAction(_ action: String) -> String {
        switch action {
        case "CHECKLIST_ITEM_FAILED": return "Voce NON OK"
        case "CHECKLIST_ALERT_RESOLVED": return "Criticità risolta"
        default: return action.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func humanTemperatureAction(_ action: String) -> String {
        switch action {
        case "TEMPERATURE_ALERT_RESOLVED": return "Allarme temperatura risolto"
        default: return action.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func traceabilityActionLabel(_ action: TraceabilityActionType) -> String {
        switch action {
        case .expired: return "Scadenza"
        case .rejected: return "Respinto"
        case .nonCompliance: return "Non conformità"
        case .withdrawn: return "Ritiro / scarto"
        case .created: return "Creazione record"
        case .linkedToProduction: return "Collegamento produzione"
        }
    }
}
