import Foundation

/// Vista logica sui dati SwiftData di ricezione merci per periodo (non è un file).
enum GoodsReceiptRegister {
    struct Row {
        let product: String
        let category: String
        let supplier: String
        let lot: String
        let expiry: String
        let receivedAt: String
        let temperatureRead: String
        let temperatureRange: String
        let temperatureOutcome: String
        let checklist: String
        let conformity: String
        let notes: String
        let operatorName: String
        let photoData: Data?
        let photoCount: Int
    }

    static func rows(
        in interval: DateInterval,
        receipts: [GoodsReceipt],
        images: [ProductImage] = [],
        df: DateFormatter
    ) -> [Row] {
        let filtered = receipts
            .filter { interval.contains($0.receivedAt) }
            .sorted { $0.receivedAt > $1.receivedAt }

        return filtered.map { r in
            let checklistIssues = r.checklistResults.filter { $0.value == .notOk }
            let checklistText: String = {
                if checklistIssues.isEmpty {
                    return r.checklistResults.isEmpty ? "—" : "Conforme"
                }
                return checklistIssues.map { c in
                    let note = (c.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let suffix = note.isEmpty ? "" : " (\(note))"
                    return "\(c.item.rawValue): NON OK\(suffix)"
                }.joined(separator: "; ")
            }()

            let temp = r.temperatureValue.map { String(format: "%.1f °C", $0) } ?? "—"
            let range: String = {
                let a = r.minAllowed.map { String(format: "%.1f", $0) } ?? "—"
                let b = r.maxAllowed.map { String(format: "%.1f", $0) } ?? "—"
                return "\(a) … \(b) °C"
            }()

            let photos = ProductImageBytesResolver.allPhotos(receipt: r, images: images)

            return Row(
                product: r.productNameSnapshot,
                category: r.category.rawValue,
                supplier: r.supplierNameSnapshot,
                lot: r.lotNumber ?? "—",
                expiry: r.expiryDate.map { df.string(from: $0) } ?? "",
                receivedAt: df.string(from: r.receivedAt),
                temperatureRead: temp,
                temperatureRange: range,
                temperatureOutcome: r.temperatureStatus.label,
                checklist: checklistText.isEmpty ? "—" : checklistText,
                conformity: r.status.label,
                notes: (r.notes ?? "").isEmpty ? "—" : (r.notes ?? ""),
                operatorName: r.createdByNameSnapshot,
                photoData: photos.first,
                photoCount: photos.count
            )
        }
    }
}
