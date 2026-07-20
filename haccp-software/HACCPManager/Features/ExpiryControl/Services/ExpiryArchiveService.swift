import Foundation
import SwiftData

/// Archiviazione operativa da Controllo scadenze: esce dalla lista attiva, resta in Storia e Documenti.
struct ExpiryArchiveService {

    func archive(
        record: TraceabilityRecord,
        kind: ExpiryLotClosureKind = .finished,
        note: String? = nil,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard record.productStatus != .used, record.productStatus != .rejected else { return }
        guard kind.isSelectable(for: record) else {
            throw NSError(
                domain: "ExpiryArchiveService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "«Scaduto» è disponibile solo senza data registrata, oppure dopo la scadenza."]
            )
        }
        if kind.requiresNote {
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                throw NSError(
                    domain: "ExpiryArchiveService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Indica la motivazione."]
                )
            }
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notePart = (trimmedNote?.isEmpty == false) ? " — \(trimmedNote!)" : ""
        let scope = record.isProductionBatchOutput ? "Produzione" : "Ingrediente"
        // Es. «Produzione Terminato» — parsato in Storia come badge «Terminato».
        let detail = "\(scope) \(kind.logDetail)\(notePart)"

        // Non soft-hide: deve restare visibile in Storia. Solo stato operativo USED.
        record.productStatus = .used
        record.operationalClosedAt = Date()

        if let trimmedNote, !trimmedNote.isEmpty {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            let line = "[\(kind.logDetail) \(stamp)] \(trimmedNote)"
            if let existing = record.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
                record.notes = "\(existing)\n\(line)"
            } else {
                record.notes = line
            }
        }

        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .withdrawn,
                operatorName: user.name,
                detail: detail
            )
        )

        DocumentMovementRecorder.recordLotClosedFromExpiryControl(
            record: record,
            outcomeLabel: kind.logDetail,
            note: trimmedNote,
            user: user,
            modelContext: modelContext
        )

        // Non soft-archiviare il batch: la chiusura resta in Storia; nascondere è solo MASTER.

        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext,
            delaySeconds: 1
        )
    }
}
