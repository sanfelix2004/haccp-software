import Foundation
import SwiftData

struct GoodsReceiptTraceabilityService {
    func createTraceabilityItem(
        receipt: GoodsReceipt,
        modelContext: ModelContext
    ) {
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
        traceability.currentStatusRaw = "DISPONIBILE"
        traceability.productStatus = .available
        modelContext.insert(traceability)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: traceability.id,
                actionType: .created,
                operatorName: receipt.createdByNameSnapshot
            )
        )
    }
}
