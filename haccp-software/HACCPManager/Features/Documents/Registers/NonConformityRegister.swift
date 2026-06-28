import Foundation

/// Registro non conformità da ricezioni e tracciabilità (dati reali).
enum NonConformityRegister {
    struct Row {
        let product: String
        let lot: String
        let reason: String
        let correctiveAction: String
        let date: String
        let operatorName: String
        let source: String
        let stato: String
        let risoltaDa: String
        let risoltaIl: String
    }

    private static func receiptIsNonConformityCase(_ status: GoodsReceiptStatus) -> Bool {
        switch status {
        case .nonConforme, .rejected, .acceptedWithNotes: return true
        case .conforme: return false
        }
    }

    static func rows(
        in interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        df: DateFormatter
    ) -> [Row] {
        _ = images
        var rows: [Row] = []

        for r in receipts where interval.contains(r.receivedAt) {
            guard receiptIsNonConformityCase(r.status) else { continue }

            var reasonParts: [String] = [r.status.label]
            if let n = r.notes, !n.isEmpty { reasonParts.append(n) }
            let reason = reasonParts.joined(separator: " — ")

            let resolvedAt = r.nonComplianceResolvedAt
            let stato = resolvedAt == nil ? "Attiva" : "Risolta"
            let risoltaIl = resolvedAt.map { df.string(from: $0) } ?? "—"
            let risoltaDa = (r.nonComplianceResolvedByNameSnapshot ?? "").isEmpty ? "—" : (r.nonComplianceResolvedByNameSnapshot ?? "")

            rows.append(Row(
                product: r.productNameSnapshot,
                lot: r.lotNumber ?? "—",
                reason: reason,
                correctiveAction: (r.correctiveAction ?? "").isEmpty ? "—" : (r.correctiveAction ?? ""),
                date: df.string(from: r.receivedAt),
                operatorName: r.createdByNameSnapshot,
                source: "Ricezione merci",
                stato: stato,
                risoltaDa: risoltaDa,
                risoltaIl: risoltaIl
            ))
        }

        for t in traceability where interval.contains(t.receivedAt) {
            guard t.isNonCompliant
                || !(t.nonComplianceNote ?? "").isEmpty
                || !(t.nonComplianceCorrectiveAction ?? "").isEmpty
            else { continue }

            let reason = [
                t.isNonCompliant ? "Non conformità segnalata" : nil,
                t.nonComplianceNote
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")

            let corrective = (t.nonComplianceCorrectiveAction ?? "").isEmpty
                ? "—"
                : (t.nonComplianceCorrectiveAction ?? "")

            let resolvedAt = t.nonComplianceResolvedAt
            let stato = resolvedAt == nil ? "Attiva" : "Risolta"
            let risoltaIl = resolvedAt.map { df.string(from: $0) } ?? "—"
            let risoltaDa = (t.nonComplianceResolvedByNameSnapshot ?? "").isEmpty ? "—" : (t.nonComplianceResolvedByNameSnapshot ?? "")

            rows.append(Row(
                product: t.productName,
                lot: t.lotCode.isEmpty ? "—" : t.lotCode,
                reason: reason.isEmpty ? "—" : reason,
                correctiveAction: corrective,
                date: df.string(from: t.receivedAt),
                operatorName: t.createdByNameSnapshot,
                source: "Tracciabilità",
                stato: stato,
                risoltaDa: risoltaDa,
                risoltaIl: risoltaIl
            ))
        }

        return rows.sorted { $0.date > $1.date }
    }
}
