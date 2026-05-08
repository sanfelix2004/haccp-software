import Foundation
import SwiftData

struct GoodsReceiptTraceabilityService {
    @discardableResult
    func createTraceabilityItem(
        receipt: GoodsReceipt,
        modelContext: ModelContext
    ) -> TraceabilityRecord {
        let isRejected = receipt.status == .nonConforme || receipt.status == .rejected
        let traceability = TraceabilityRecord(
            restaurantId: receipt.restaurantId,
            productName: receipt.productNameSnapshot,
            lotCode: receipt.lotNumber ?? "",
            supplier: receipt.supplierNameSnapshot,
            source: .receipt,
            goodsReceiptId: receipt.id,
            receivedAt: receipt.receivedAt,
            expiryDate: receipt.expiryDate,
            photoData: receipt.photoData,
            createdByUserId: receipt.createdByUserId ?? UUID(),
            createdByNameSnapshot: receipt.createdByNameSnapshot,
            notes: receipt.notes,
            operatorSignature: receipt.createdByNameSnapshot
        )
        traceability.categoryRaw = receipt.categoryRaw
        traceability.goodsReceiptStatusRaw = receipt.status.rawValue
        traceability.currentStatusRaw = "DISPONIBILE"
        traceability.isNonCompliant = isRejected
        traceability.nonComplianceNote = isRejected ? receipt.notes : nil
        traceability.nonComplianceCorrectiveAction = isRejected ? receipt.correctiveAction : nil
        traceability.productStatus = isRejected ? .rejected : .available
        modelContext.insert(traceability)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: traceability.id,
                actionType: isRejected ? .nonCompliance : .created,
                operatorName: receipt.createdByNameSnapshot
            )
        )
        return traceability
    }
}
