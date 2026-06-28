import Foundation
import SwiftData

struct ProduzioneBatchService {
    func nextBatchCode(
        productionId: UUID,
        restaurantId: UUID,
        modelContext: ModelContext
    ) -> String {
        let descriptor = FetchDescriptor<ProduzioneBatch>()
        let existing = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.restaurantId == restaurantId && $0.productionId == productionId }
        let n = existing.count + 1
        return String(format: "Batch #%02d", n)
    }

    @discardableResult
    func startBatch(
        production: Production,
        user: LocalUser,
        modelContext: ModelContext,
        producedAt: Date = Date()
    ) throws -> ProduzioneBatch {
        let batchCode = nextBatchCode(
            productionId: production.id,
            restaurantId: production.restaurantId,
            modelContext: modelContext
        )
        let batch = ProduzioneBatch(
            restaurantId: production.restaurantId,
            productionId: production.id,
            productionNameSnapshot: production.name,
            batchCode: batchCode,
            producedAt: producedAt,
            status: .inCorso,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(batch)
        try modelContext.save()
        return batch
    }

    func completeBatch(
        batch: ProduzioneBatch,
        internalExpiryAt: Date?,
        ingredientCount: Int,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard ingredientCount > 0 else {
            throw NSError(
                domain: "ProduzioneBatchService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Aggiungi almeno un ingrediente tracciato via foto."]
            )
        }
        batch.internalExpiryAt = internalExpiryAt
        batch.status = .completato
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: batch.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    func cancelBatch(_ batch: ProduzioneBatch, modelContext: ModelContext) throws {
        batch.status = .annullato
        try modelContext.save()
    }

    func batches(
        restaurantId: UUID,
        modelContext: ModelContext,
        includeArchived: Bool = false
    ) -> [ProduzioneBatch] {
        let descriptor = FetchDescriptor<ProduzioneBatch>(
            sortBy: [SortDescriptor(\ProduzioneBatch.createdAt, order: .reverse)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.restaurantId == restaurantId && (includeArchived || !$0.isArchived) }
    }
}
