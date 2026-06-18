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
        let imageData: Data?
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
        let imageMap = Dictionary(grouping: images, by: \.receivedItemId)

        let filtered = records
            .filter { interval.contains($0.receivedAt) }
            .sorted { $0.receivedAt > $1.receivedAt }

        return filtered.map { t in
            let linkList = linksByReceived[t.id] ?? []
            let prodNames = linkList.compactMap { prodById[$0.productionId]?.name }.joined(separator: ", ")

            var ncParts: [String] = []
            if t.isNonCompliant { ncParts.append("Segnalata") }
            if let n = t.nonComplianceNote, !n.isEmpty { ncParts.append(n) }
            if let a = t.nonComplianceCorrectiveAction, !a.isEmpty { ncParts.append("Azione: \(a)") }
            if let raw = t.goodsReceiptStatusRaw, let st = GoodsReceiptStatus(rawValue: raw), st != .conforme {
                ncParts.append("Ricezione: \(st.label)")
            }

            let imgs = imageMap[t.id] ?? []
            let photo: Data? = {
                if let nc = imgs.first(where: { $0.type == .nonComplianceRequired }) {
                    if let d = nc.imageData { return d }
                    if let p = nc.localPath { return try? Data(contentsOf: URL(fileURLWithPath: p)) }
                }
                if let d = imgs.compactMap(\.imageData).first { return d }
                if let path = imgs.compactMap(\.localPath).first {
                    return try? Data(contentsOf: URL(fileURLWithPath: path))
                }
                return t.photoData
            }()

            return Row(
                product: t.productName,
                lot: t.lotCode.isEmpty ? "—" : t.lotCode,
                supplier: t.supplier,
                receivedAt: df.string(from: t.receivedAt),
                status: t.productStatus.label,
                productions: prodNames.isEmpty ? "—" : prodNames,
                nonCompliance: ncParts.isEmpty ? "—" : ncParts.joined(separator: "; "),
                operatorName: t.createdByNameSnapshot,
                imageData: photo
            )
        }
    }
}
