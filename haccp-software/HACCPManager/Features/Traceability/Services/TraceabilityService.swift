import Foundation
import SwiftData

struct TraceabilityService {
    func addRecord(
        restaurantId: UUID,
        productName: String,
        lotCode: String,
        supplier: String,
        receivedAt: Date,
        expiryDate: Date?,
        productionReference: String?,
        photoData: Data?,
        user: LocalUser,
        notes: String?,
        modelContext: ModelContext
    ) throws {
        let trimmedProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduct.isEmpty else { return }

        let record = TraceabilityRecord(
            restaurantId: restaurantId,
            productName: trimmedProduct,
            lotCode: lotCode.trimmingCharacters(in: .whitespacesAndNewlines),
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            receivedAt: receivedAt,
            expiryDate: expiryDate,
            productionReference: productionReference?.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            operatorSignature: user.name
        )
        modelContext.insert(record)
        try modelContext.save()
    }
}
