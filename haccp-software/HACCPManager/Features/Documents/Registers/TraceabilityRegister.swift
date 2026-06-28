import Foundation

/// Vista logica sui dati SwiftData di tracciabilità per periodo.
enum TraceabilityRegister {
    struct Row {
        let product: String
        let lot: String
        let supplier: String
        let receivedAt: String
        let status: String
        let productions: String
        let nonCompliance: String
        let operatorName: String
    }

    static func rows(
        in interval: DateInterval,
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        df: DateFormatter
    ) -> [Row] {
        let prodById = Dictionary(uniqueKeysWithValues: productions.map { ($0.id, $0) })
        let linksByReceived = Dictionary(grouping: links, by: \.receivedItemId)

        let filtered = records
            .filter { interval.contains($0.receivedAt) }
            .sorted { $0.receivedAt > $1.receivedAt }

        return filtered.map { t in
            let linkList = linksByReceived[t.id] ?? []
            let prodNames = linkList.compactMap { prodById[$0.productionId]?.name }.joined(separator: ", ")
            let productionsLabel: String = {
                if !prodNames.isEmpty { return prodNames }
                if let ref = t.productionReference?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
                    return ref
                }
                return "—"
            }()

            var ncParts: [String] = []
            if t.isNonCompliant { ncParts.append("Segnalata") }
            if let n = t.nonComplianceNote, !n.isEmpty { ncParts.append(n) }
            if let a = t.nonComplianceCorrectiveAction, !a.isEmpty { ncParts.append("Azione: \(a)") }
            if let raw = t.goodsReceiptStatusRaw, let st = GoodsReceiptStatus(rawValue: raw), st != .conforme {
                ncParts.append("Ricezione: \(st.label)")
            }

            return Row(
                product: t.productName,
                lot: t.lotCode.isEmpty ? "—" : t.lotCode,
                supplier: t.supplier,
                receivedAt: df.string(from: t.receivedAt),
                status: t.productStatus.label,
                productions: productionsLabel,
                nonCompliance: ncParts.isEmpty ? "—" : ncParts.joined(separator: "; "),
                operatorName: t.createdByNameSnapshot
            )
        }
    }
}
