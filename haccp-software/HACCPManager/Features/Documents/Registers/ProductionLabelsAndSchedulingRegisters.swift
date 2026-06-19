import Foundation

enum ProductionLabelsRegister {
    struct Row {
        let product: String
        let lot: String
        let category: String
        let supplier: String
        let producedAt: String
        let expiresAt: String
        let status: String
        let source: String
        let reprints: String
        let operatorName: String
        let notes: String
    }

    static func rows(in interval: DateInterval, labels: [ProductionLabelRecord], df: DateFormatter) -> [Row] {
        labels
            .filter { interval.contains($0.createdAt) }
            .sorted { $0.createdAt > $1.createdAt }
            .map { label in
                Row(
                    product: label.productName,
                    lot: label.lotCode ?? HACCPRegisterCopy.notAvailable,
                    category: label.category ?? HACCPRegisterCopy.notAvailable,
                    supplier: label.supplier ?? HACCPRegisterCopy.notAvailable,
                    producedAt: df.string(from: label.productionDate),
                    expiresAt: df.string(from: label.expiryDate),
                    status: label.productStatus.label,
                    source: label.sourceModule.displayLabel,
                    reprints: label.reprintCount > 0 ? "\(label.reprintCount)" : "0",
                    operatorName: label.createdByNameSnapshot,
                    notes: (label.notes ?? "").isEmpty ? HACCPRegisterCopy.notAvailable : (label.notes ?? "")
                )
            }
    }
}
