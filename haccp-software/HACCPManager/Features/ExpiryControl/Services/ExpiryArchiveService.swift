import Foundation
import SwiftData

/// Chiusura operativa da Controllo scadenze.
/// - Terminato → solo Storia (nessun movimento Documenti).
/// - Scartato → Storia + Documenti, motivazione obbligatoria.
/// - Scaduto → Storia + Documenti (scarto per scadenza).
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

        let trimmedNote: String? = {
            guard kind.requiresNote || kind.recordsInDocuments else { return nil }
            let t = note?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t?.isEmpty == false) ? t : nil
        }()
        // Motivazione solo su Scartato (obbligatoria); note opzionali su Scaduto se presenti.
        let noteForStorage: String? = {
            if kind == .finished { return nil }
            return trimmedNote
        }()
        let notePart = noteForStorage.map { " — \($0)" } ?? ""
        let scope = record.isProductionBatchOutput ? "Produzione" : "Ingrediente"
        // Es. «Produzione Terminato» — parsato in Storia come badge «Terminato».
        let detail = "\(scope) \(kind.logDetail)\(notePart)"

        // Non soft-hide: resta visibile in Storia con lo stato corretto.
        record.productStatus = kind.closedProductStatus
        record.operationalClosedAt = Date()

        if let noteForStorage {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            let line = "[\(kind.logDetail) \(stamp)] \(noteForStorage)"
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

        // Terminato: solo Storia. Scartato/Scaduto: anche Documenti.
        if kind.recordsInDocuments {
            DocumentMovementRecorder.recordLotClosedFromExpiryControl(
                record: record,
                outcomeLabel: kind.logDetail,
                note: noteForStorage,
                user: user,
                modelContext: modelContext
            )
        }

        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
        if kind.recordsInDocuments {
            HACCPArchiveSyncCoordinator.requestDeferredSync(
                restaurantId: record.restaurantId,
                user: user,
                modelContext: modelContext,
                delaySeconds: 1
            )
        }
    }
}
