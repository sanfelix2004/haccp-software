import Foundation
import SwiftData

/// Controllo MASTER sullo storico operativo: nasconde voci dalla UI senza cancellare i documenti.
struct HistoryControlService {

    /// Rimuove una produzione completata dallo storico/hub operativo.
    /// Soft-archive: i dati e i log restano; Documenti ricevono un movimento permanente.
    func removeProductionFromHistory(
        batch: ProduzioneBatch,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard !batch.isArchived else { return }

        let ingredientLines = ingredientSummaries(for: batch, modelContext: modelContext)

        DocumentMovementRecorder.recordProductionRemovedFromHistory(
            batch: batch,
            ingredientLines: ingredientLines,
            user: user,
            modelContext: modelContext
        )

        batch.isArchived = true
        batch.archivedAt = Date()

        // Nasconde il piatto finito dalle viste operative; non tocca i log.
        let batchId = batch.id
        var outputDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> { $0.produzioneBatchId == batchId }
        )
        let outputs = (try? modelContext.fetch(outputDescriptor)) ?? []
        for record in outputs where !record.isArchived {
            record.isArchived = true
            record.archivedAt = Date()
            modelContext.insert(
                TraceabilityLog(
                    receivedItemId: record.id,
                    productionId: batch.productionId,
                    actionType: .removedFromHistory,
                    operatorName: user.name,
                    detail: "Lotto produzione \(batch.batchCode) — nascosto dallo storico (conservato in Documenti)"
                )
            )
        }

        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: batch.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    /// Soft-delete voce tracciabilità: resta in Documenti, sparisce dallo storico operativo.
    func softDeleteTraceabilityRecord(
        record: TraceabilityRecord,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard !record.isArchived else { return }

        DocumentMovementRecorder.record(
            restaurantId: record.restaurantId,
            kind: .traceabilitySoftDeleted,
            user: user,
            entityType: "TraceabilityRecord",
            entityId: record.id,
            productionName: record.productName,
            lotCode: record.lotCode.nilIfEmpty,
            summary: "\(record.productName) · Lotto \(record.lotCode.isEmpty ? "—" : record.lotCode) · \(record.supplier.isEmpty ? "—" : record.supplier)",
            modelContext: modelContext
        )

        record.isArchived = true
        record.archivedAt = Date()
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .removedFromHistory,
                operatorName: user.name,
                detail: "Nascosto dallo storico operativo — traccia conservata in Documenti"
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    private func ingredientSummaries(for batch: ProduzioneBatch, modelContext: ModelContext) -> [String] {
        let batchId = batch.id
        let tracked = ((try? modelContext.fetch(FetchDescriptor<IngredienteTracciato>())) ?? [])
            .filter { $0.produzioneBatchId == batchId }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }

        if !tracked.isEmpty {
            return tracked.map { item in
                let name = item.ingredientNameAssigned
                    ?? item.ingredientNameHint
                    ?? "Ingrediente"
                let lot = item.lotCodeExtracted?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "—"
                return "\(name) (lotto \(lot.isEmpty ? "—" : lot))"
            }
        }

        let links = ((try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? [])
            .filter { $0.productionId == batch.productionId }
        let recordIds = Set(links.map(\.receivedItemId))
        let records = ((try? modelContext.fetch(FetchDescriptor<TraceabilityRecord>())) ?? [])
            .filter { recordIds.contains($0.id) }
        return records.map { "\($0.productName) (lotto \($0.lotCode.isEmpty ? "—" : $0.lotCode))" }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
