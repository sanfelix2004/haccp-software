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
    ) throws -> TraceabilityRecord {
        let trimmedProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduct.isEmpty else {
            throw NSError(
                domain: "TraceabilityService",
                code: 4001,
                userInfo: [NSLocalizedDescriptionKey: "Il nome prodotto e obbligatorio."]
            )
        }

        let record = TraceabilityRecord(
            restaurantId: restaurantId,
            productName: trimmedProduct,
            lotCode: lotCode.trimmingCharacters(in: .whitespacesAndNewlines),
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            receivedAt: receivedAt,
            expiryDate: expiryDate,
            productionReference: productionReference?.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: nil,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            operatorSignature: user.name
        )
        modelContext.insert(record)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .created,
                operatorName: user.name
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
        return record
    }

    func markNonCompliant(
        record: TraceabilityRecord,
        note: String,
        correctiveAction: String,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            throw NSError(domain: "TraceabilityService", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Inserisci il motivo della non conformità."])
        }
        guard !trimmedAction.isEmpty else {
            throw NSError(domain: "TraceabilityService", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Inserisci l'azione correttiva obbligatoria."])
        }

        record.isNonCompliant = true
        record.nonComplianceNote = trimmedNote
        record.nonComplianceCorrectiveAction = trimmedAction
        record.productStatus = .rejected
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .nonCompliance,
                operatorName: user.name
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    func markWithdrawn(
        record: TraceabilityRecord,
        kind: TraceabilityWithdrawalKind,
        note: String,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard record.canBeWithdrawn else {
            throw traceabilityError(
                4010,
                "Solo i lotti scaduti possono essere segnati come ritirati o scartati."
            )
        }

        if record.productStatus != .expired,
           ProductExpiryEvaluator.shouldMarkSystemExpired(record) {
            record.productStatus = .expired
            modelContext.insert(
                TraceabilityLog(
                    receivedItemId: record.id,
                    actionType: .expired,
                    operatorName: "Sistema"
                )
            )
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let closureLine = "[\(kind.label) \(stamp)]\(trimmedNote.isEmpty ? "" : " \(trimmedNote)")"
        if let existing = record.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            record.notes = "\(existing)\n\(closureLine)"
        } else {
            record.notes = closureLine
        }

        let auditDetail = trimmedNote.isEmpty ? kind.label : "\(kind.label) — \(trimmedNote)"
        record.productStatus = .used
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .withdrawn,
                operatorName: user.name,
                detail: auditDetail
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    /// Soft-delete: nasconde dalla UI operativa, conserva log e scrive movimento Documenti.
    func deleteRecord(
        record: TraceabilityRecord,
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        user: LocalUser? = nil,
        modelContext: ModelContext
    ) throws {
        _ = links
        _ = logs
        _ = images
        if let user {
            try HistoryControlService().softDeleteTraceabilityRecord(
                record: record,
                user: user,
                modelContext: modelContext
            )
        } else {
            // Fallback legacy: soft-archive senza utente (nessuna cancellazione fisica log).
            guard !record.isArchived else { return }
            record.isArchived = true
            record.archivedAt = Date()
            modelContext.insert(
                TraceabilityLog(
                    receivedItemId: record.id,
                    actionType: .removedFromHistory,
                    operatorName: "Sistema",
                    detail: "Nascosto dallo storico — traccia conservata in Documenti"
                )
            )
            try modelContext.save()
        }
    }

    /// Elimina la voce di tracciabilità dalla UI (soft): indipendente da Ricezione merci.
    /// I log e la traccia Documenti non vengono mai cancellati.
    func deleteTraceabilityEntry(
        record: TraceabilityRecord,
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        _ = links
        _ = logs
        _ = images
        try HistoryControlService().softDeleteTraceabilityRecord(
            record: record,
            user: user,
            modelContext: modelContext
        )
    }

    func addImage(
        to record: TraceabilityRecord,
        imageData: Data,
        type: ProductImageType,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        modelContext.insert(
            ProductImage(
                receivedItemId: record.id,
                imageData: StoredImageCompression.preparedForStorage(imageData),
                localPath: nil,
                type: type,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }

    func exportTraceabilityReport(
        records: [TraceabilityRecord],
        links: [TraceabilityLink],
        productions: [Production]
    ) -> String {
        let productionMap = Dictionary(uniqueKeysWithValues: productions.map { ($0.id, $0.name) })
        let header = "prodotto,fornitore,lotto,stato,data_ricezione,data_scadenza,produzioni"
        let rows = records.map { record in
            let linkedNames = links
                .filter { $0.receivedItemId == record.id }
                .compactMap { productionMap[$0.productionId] }
                .joined(separator: " | ")
            return [
                csvCell(record.productName),
                csvCell(record.supplier),
                csvCell(record.lotCode),
                csvCell(record.productStatus.label),
                csvCell(record.receivedAt.formatted(date: .abbreviated, time: .shortened)),
                csvCell(record.expiryDate?.formatted(date: .abbreviated, time: .omitted) ?? ""),
                csvCell(linkedNames)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func csvCell(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func traceabilityError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "TraceabilityService", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
