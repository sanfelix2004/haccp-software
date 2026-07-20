import Foundation

/// Riepilogo leggibile del ciclo di vita di un lotto (creazione → associazioni → chiusura).
struct TraceabilityLifecycleSummary: Equatable {
    struct Association: Equatable, Identifiable {
        var id: String { "\(productionName)-\(occurredAt.timeIntervalSince1970)-\(operatorName)" }
        let productionName: String
        let occurredAt: Date
        let operatorName: String
    }

    struct Closure: Equatable {
        let occurredAt: Date
        let operatorName: String
        let outcome: String
        let note: String?
    }

    let createdAt: Date
    let createdBy: String
    let lotLabel: String
    let lotValue: String
    let supplier: String
    let expiryDate: Date?
    let associations: [Association]
    let closure: Closure?
    let statusLabel: String

    var isClosed: Bool { closure != nil || statusLabel == ProductStatus.used.label || statusLabel == ProductStatus.rejected.label }

    var createdLine: String {
        "Creato il \(Self.fmtDateTime(createdAt)) da \(createdBy)"
    }

    var closureLine: String? {
        guard let closure else { return nil }
        var line = "Chiuso il \(Self.fmtDateTime(closure.occurredAt)) da \(closure.operatorName) — \(closure.outcome)"
        if let note = closure.note, !note.isEmpty {
            line += " (\(note))"
        }
        return line
    }

    static func build(
        record: TraceabilityRecord,
        logs: [TraceabilityLog],
        productionsById: [UUID: Production] = [:]
    ) -> TraceabilityLifecycleSummary {
        let sorted = logs.sorted { $0.timestamp < $1.timestamp }

        let associations: [Association] = sorted.compactMap { log in
            guard log.actionType == .linkedToProduction else { return nil }
                        let name = log.linkedProductionDisplayName(productionsById: productionsById)
                            ?? log.productionId.flatMap { productionsById[$0]?.name }
                            ?? log.detail
                            ?? "Produzione"
            return Association(
                productionName: name,
                occurredAt: log.timestamp,
                operatorName: log.operatorName
            )
        }

        let closureLog = sorted.last(where: {
            $0.actionType == .withdrawn || $0.actionType == .archivedFromExpiryControl
        })
        let closure: Closure? = closureLog.map { log in
            Closure(
                occurredAt: log.timestamp,
                operatorName: log.operatorName,
                outcome: humanOutcome(from: log),
                note: extractedNote(from: log.detail)
            )
        }

        let isProduction = record.isProductionBatchOutput
        return TraceabilityLifecycleSummary(
            createdAt: record.createdAt,
            createdBy: record.createdByNameSnapshot,
            lotLabel: isProduction ? "Lotto produzione" : "Lotto fornitore",
            lotValue: record.lotCode.isEmpty ? "—" : record.lotCode,
            supplier: record.supplier.isEmpty ? "—" : record.supplier,
            expiryDate: record.expiryDate,
            associations: associations,
            closure: closure,
            statusLabel: record.productStatus.label
        )
    }

    private static func humanOutcome(from log: TraceabilityLog) -> String {
        let detail = log.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if detail.localizedCaseInsensitiveContains("scadut") { return "Scaduto" }
        if detail.localizedCaseInsensitiveContains("scartat") { return "Scartato" }
        if detail.localizedCaseInsensitiveContains("terminat") { return "Terminato" }
        if detail.localizedCaseInsensitiveContains("usat")
            || detail.localizedCaseInsensitiveContains("ritirat") {
            return "Usato"
        }
        if log.actionType == .archivedFromExpiryControl {
            return detail.isEmpty ? "Chiuso da scadenze" : firstOutcomeToken(detail)
        }
        if log.actionType == .withdrawn {
            return detail.isEmpty ? "Usato" : firstOutcomeToken(detail)
        }
        return detail.isEmpty ? "Chiuso" : firstOutcomeToken(detail)
    }

    private static func firstOutcomeToken(_ detail: String) -> String {
        let cleaned = detail
            .replacingOccurrences(of: "Produzione ", with: "")
            .replacingOccurrences(of: "Ingrediente ", with: "")
        if let beforeDash = cleaned.split(separator: "—").first {
            let token = beforeDash.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty { return token.prefix(1).uppercased() + token.dropFirst() }
        }
        return cleaned
    }

    private static func extractedNote(from detail: String?) -> String? {
        guard let detail, let range = detail.range(of: "—") else { return nil }
        let note = detail[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? nil : note
    }

    private static func fmtDateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func fmtDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
