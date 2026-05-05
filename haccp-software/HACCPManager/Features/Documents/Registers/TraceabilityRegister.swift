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
        let events: String
        let eventTimestamps: String
        let operatorName: String
        let productImageData: Data?
        let eventImageData: Data?
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
        let logsByReceived = Dictionary(grouping: logs, by: \.receivedItemId)
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
            if let raw = t.goodsReceiptStatusRaw, let st = GoodsReceiptStatus(rawValue: raw) {
                ncParts.append("Conformità ricezione: \(st.label)")
            }

            let sortedLogs = (logsByReceived[t.id] ?? []).sorted { $0.timestamp > $1.timestamp }
            let logLines = sortedLogs.map { log in
                "\(df.string(from: log.timestamp)) — \(log.operatorName) — \(traceabilityActionLabel(log.actionType))"
            }
            let eventTs = sortedLogs.map { df.string(from: $0.timestamp) }.joined(separator: "; ")

            let imgs = imageMap[t.id] ?? []
            let productImg = imgs.compactMap(\.imageData).first
                ?? imgs.compactMap { img -> Data? in
                    guard let path = img.localPath else { return nil }
                    return try? Data(contentsOf: URL(fileURLWithPath: path))
                }.first
                ?? t.photoData

            let eventImg: Data? = {
                guard let i = imgs.first(where: { $0.type == .nonComplianceRequired }) else { return nil }
                if let d = i.imageData { return d }
                if let p = i.localPath { return try? Data(contentsOf: URL(fileURLWithPath: p)) }
                return nil
            }()

            return Row(
                product: t.productName,
                lot: t.lotCode.isEmpty ? "—" : t.lotCode,
                supplier: t.supplier,
                receivedAt: df.string(from: t.receivedAt),
                status: t.productStatus.label,
                productions: prodNames.isEmpty ? "—" : prodNames,
                nonCompliance: ncParts.isEmpty ? "—" : ncParts.joined(separator: "; "),
                events: logLines.isEmpty ? "—" : logLines.joined(separator: "; "),
                eventTimestamps: eventTs.isEmpty ? "—" : eventTs,
                operatorName: t.createdByNameSnapshot,
                productImageData: productImg,
                eventImageData: eventImg ?? productImg
            )
        }
    }

    private static func traceabilityActionLabel(_ action: TraceabilityActionType) -> String {
        switch action {
        case .created: return "Creazione record"
        case .linkedToProduction: return "Collegamento a produzione"
        case .expired: return "Scadenza"
        case .rejected: return "Respinto"
        case .nonCompliance: return "Non conformità"
        }
    }
}
