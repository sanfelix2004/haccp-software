import Foundation
import SwiftData

/// Controllo MASTER sullo storico operativo. L’eliminazione di una produzione è definitiva
/// (Storia, Tracciabilità e PDF successivi usano la stessa fonte dati).
struct HistoryControlService {

    /// Rimuove definitivamente una produzione da Storia, Tracciabilità e PDF successivi.
    func deleteProductionPermanently(
        batch: ProduzioneBatch,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let batchId = batch.id
        let lottoService = LottoFotoService()
        let lottoLinks = ((try? modelContext.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? [])
            .filter { $0.produzioneBatchId == batchId }
        let lottoIds = Set(lottoLinks.map(\.lottoFotoId))
        if !lottoIds.isEmpty {
            let lottos = ((try? modelContext.fetch(FetchDescriptor<LottoFoto>())) ?? [])
                .filter { lottoIds.contains($0.id) }
            for lotto in lottos {
                try lottoService.delete(lotto, modelContext: modelContext)
            }
        }
        try TraceabilityService().hardPurgeProductionBatch(
            batch: batch,
            unlinkIncoming: true,
            user: user,
            modelContext: modelContext
        )
        KitchenProcessNotifications.postRecordsDidChange()
    }

    /// Rimuove una produzione dallo storico/hub.
    /// Con motivo `.error` → cancellazione definitiva (come Tracciabilità).
    /// Altrimenti soft-hide (resta in Documenti). Ingredienti scollegati se richiesto.
    func removeProductionFromHistory(
        batch: ProduzioneBatch,
        reason: HistoryRemovalReason,
        note: String? = nil,
        user: LocalUser,
        modelContext: ModelContext,
        unlinkIngredients: Bool = true
    ) throws {
        guard !batch.isArchived || reason == .error else { return }
        if reason.requiresNote {
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                throw NSError(
                    domain: "HistoryControlService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Per «Altro» indica una nota."]
                )
            }
        }

        // Errore di registrazione: niente soft-hide, cancellazione totale.
        if reason == .error {
            try TraceabilityService().hardPurgeProductionBatch(
                batch: batch,
                unlinkIncoming: unlinkIngredients,
                user: user,
                modelContext: modelContext
            )
            KitchenProcessNotifications.postRecordsDidChange()
            return
        }

        if unlinkIngredients {
            try TraceabilityService().unlinkIncomingLots(
                productionId: batch.productionId,
                batchId: batch.id,
                modelContext: modelContext
            )
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let ingredientLines = ingredientSummaries(for: batch, modelContext: modelContext)
        let reasonDetail = Self.auditDetail(reason: reason, note: trimmedNote)

        DocumentMovementRecorder.recordProductionRemovedFromHistory(
            batch: batch,
            ingredientLines: ingredientLines,
            reason: reason,
            note: trimmedNote,
            user: user,
            modelContext: modelContext
        )

        batch.isArchived = true
        batch.archivedAt = Date()
        batch.historyRemovalReason = reason
        batch.historyRemovalNote = trimmedNote

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
                    detail: "Lotto \(batch.batchCode) — nascosto dallo storico (\(reasonDetail))"
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

    /// Soft-delete / hard-purge voce tracciabilità.
    /// `.error` → cancellazione definitiva (non resta in Documenti).
    /// Altri motivi → soft-hide con audit Documenti.
    func softDeleteTraceabilityRecord(
        record: TraceabilityRecord,
        reason: HistoryRemovalReason,
        note: String? = nil,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard !record.isArchived || reason == .error else { return }
        if reason.requiresNote {
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                throw NSError(
                    domain: "HistoryControlService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Per «Altro» indica una nota."]
                )
            }
        }

        if reason == .error {
            try TraceabilityService().deleteTraceabilityEntry(
                record: record,
                links: [],
                logs: [],
                images: [],
                user: user,
                modelContext: modelContext
            )
            return
        }

        if record.isProductionBatchOutput, let batchId = record.produzioneBatchId {
            var batchDesc = FetchDescriptor<ProduzioneBatch>(
                predicate: #Predicate<ProduzioneBatch> { $0.id == batchId }
            )
            batchDesc.fetchLimit = 1
            if let batch = (try? modelContext.fetch(batchDesc))?.first, !batch.isArchived {
                try removeProductionFromHistory(
                    batch: batch,
                    reason: reason,
                    note: note,
                    user: user,
                    modelContext: modelContext
                )
                return
            }
        }

        if record.isIncomingIngredientLot {
            try unlinkIncomingRecord(record, modelContext: modelContext)
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let reasonDetail = Self.auditDetail(reason: reason, note: trimmedNote)

        DocumentMovementRecorder.record(
            restaurantId: record.restaurantId,
            kind: .traceabilitySoftDeleted,
            user: user,
            entityType: "TraceabilityRecord",
            entityId: record.id,
            productionName: record.productName,
            lotCode: record.lotCode.nilIfEmpty,
            summary: "\(record.productName) · Lotto \(record.lotCode.isEmpty ? "—" : record.lotCode) · Motivo: \(reasonDetail)",
            detailJSON: DocumentMovementRecorder.encodeRemovalJSON(
                reason: reason,
                note: trimmedNote,
                extra: [
                    "recordId": record.id.uuidString,
                    "productName": record.productName,
                    "lotCode": record.lotCode
                ]
            ),
            modelContext: modelContext
        )

        record.isArchived = true
        record.archivedAt = Date()
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .removedFromHistory,
                operatorName: user.name,
                detail: "Nascosto dallo storico operativo — \(reasonDetail)"
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    private func unlinkIncomingRecord(_ record: TraceabilityRecord, modelContext: ModelContext) throws {
        let recordId = record.id
        let links = ((try? modelContext.fetch(FetchDescriptor<TraceabilityLink>())) ?? [])
            .filter { $0.receivedItemId == recordId }
        for link in links {
            modelContext.delete(link)
        }
        if let lottoId = record.lottoFotoId {
            let lottoLinks = ((try? modelContext.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? [])
                .filter { $0.lottoFotoId == lottoId }
            for link in lottoLinks {
                modelContext.delete(link)
            }
        }
        record.productionReference = nil
    }

    static func auditDetail(reason: HistoryRemovalReason, note: String?) -> String {
        if let note, !note.isEmpty {
            return "\(reason.auditLabel): \(note)"
        }
        return reason.auditLabel
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
