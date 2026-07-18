import Foundation
import SwiftData

struct ProduzioneBatchService {
    func nextBatchCode(
        productionId: UUID,
        restaurantId: UUID,
        modelContext: ModelContext,
        producedAt: Date = Date()
    ) -> String {
        _ = productionId
        return InternalLotCodeGenerator.nextCode(
            restaurantId: restaurantId,
            producedAt: producedAt,
            modelContext: modelContext
        )
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
            modelContext: modelContext,
            producedAt: producedAt
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

    /// Garantisce un lotto interno `YYYYMMDD-XX` (migra i vecchi «Batch #01»).
    func ensureInternalLotCode(
        batch: ProduzioneBatch,
        modelContext: ModelContext
    ) throws {
        let current = batch.batchCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if InternalLotCodeGenerator.isInternalLotCode(current) { return }
        batch.batchCode = InternalLotCodeGenerator.nextCode(
            restaurantId: batch.restaurantId,
            producedAt: batch.producedAt,
            modelContext: modelContext,
            excludingBatchId: batch.id
        )
        try modelContext.save()
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
        try ensureInternalLotCode(batch: batch, modelContext: modelContext)
        batch.internalExpiryAt = internalExpiryAt
        batch.status = .completato

        let ingredientLines = ((try? modelContext.fetch(FetchDescriptor<IngredienteTracciato>())) ?? [])
            .filter { $0.produzioneBatchId == batch.id }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
            .map { item -> String in
                let name = item.ingredientNameAssigned ?? item.ingredientNameHint ?? "Ingrediente"
                let lot = item.lotCodeExtracted?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "—"
                return "\(name) (lotto \(lot.isEmpty ? "—" : lot))"
            }
        DocumentMovementRecorder.recordProductionCompleted(
            batch: batch,
            ingredientLines: ingredientLines,
            user: user,
            modelContext: modelContext
        )

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
