import Foundation

/// Vista logica sui dati SwiftData di tracciabilità per periodo.
enum TraceabilityRegister {
    struct Row {
        let product: String
        let lot: String
        let supplier: String
        let createdAt: String
        let createdBy: String
        let associations: String
        let closure: String
        let status: String
        let nonCompliance: String
        let operatorName: String
        let photoData: Data?
    }

    static func rows(
        in interval: DateInterval,
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        lottoFotos: [LottoFoto] = [],
        df: DateFormatter
    ) -> [Row] {
        let prodById = Dictionary(uniqueKeysWithValues: productions.map { ($0.id, $0) })
        let logsByRecord = Dictionary(grouping: logs, by: \.receivedItemId)

        let filtered = records
            .filter { !$0.isArchived }
            .filter { record in
                if interval.contains(record.receivedAt) || interval.contains(record.createdAt) {
                    return true
                }
                // Include lotti creati prima ma chiusi nel periodo (allinea al registro movimenti).
                let recordLogs = logsByRecord[record.id] ?? []
                return recordLogs.contains {
                    ($0.actionType == .withdrawn || $0.actionType == .archivedFromExpiryControl)
                        && interval.contains($0.timestamp)
                }
            }
            .sorted { $0.receivedAt > $1.receivedAt }

        return filtered.map { t in
            let recordLogs = logsByRecord[t.id] ?? []
            let life = TraceabilityLifecycleSummary.build(
                record: t,
                logs: recordLogs,
                productionsById: prodById
            )

            let associationsLabel: String = {
                if !life.associations.isEmpty {
                    return life.associations.map { assoc in
                        "\(assoc.productionName) (il \(df.string(from: assoc.occurredAt)) da \(assoc.operatorName))"
                    }.joined(separator: "; ")
                }
                if let ref = t.productionReference?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
                    return ref
                }
                return "—"
            }()

            let closureLabel: String = {
                if let closure = life.closure {
                    var parts = [
                        closure.outcome,
                        df.string(from: closure.occurredAt),
                        "da \(closure.operatorName)"
                    ]
                    if let note = closure.note, !note.isEmpty {
                        parts.append(note)
                    }
                    return parts.joined(separator: " · ")
                }
                if t.productStatus == .used || t.productStatus == .rejected {
                    return t.productStatus.label
                }
                return "In uso"
            }()

            var ncParts: [String] = []
            if t.isNonCompliant { ncParts.append("Segnalata") }
            if let n = t.nonComplianceNote, !n.isEmpty { ncParts.append(n) }
            if let a = t.nonComplianceCorrectiveAction, !a.isEmpty { ncParts.append("Azione: \(a)") }
            if let raw = t.goodsReceiptStatusRaw, let st = GoodsReceiptStatus(rawValue: raw), st != .conforme {
                ncParts.append("Ricezione: \(st.label)")
            }

            let photo: Data? = {
                if t.isProductionBatchOutput, let batchId = t.produzioneBatchId {
                    return ProductImageBytesResolver.productionDishPhoto(
                        batchId: batchId,
                        images: images,
                        records: [t]
                    ) ?? ProductImageBytesResolver.resolve(
                        record: t,
                        images: images,
                        lottoFotos: lottoFotos
                    )
                }
                return ProductImageBytesResolver.resolve(
                    record: t,
                    images: images,
                    lottoFotos: lottoFotos
                )
            }()

            return Row(
                product: t.productName,
                lot: life.lotValue,
                supplier: t.isProductionBatchOutput ? "Produzione interna" : life.supplier,
                createdAt: df.string(from: life.createdAt),
                createdBy: life.createdBy,
                associations: associationsLabel,
                closure: closureLabel,
                status: life.statusLabel,
                nonCompliance: ncParts.isEmpty ? "—" : ncParts.joined(separator: "; "),
                operatorName: life.createdBy,
                photoData: photo
            )
        }
    }
}
