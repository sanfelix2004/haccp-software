import Foundation
import SwiftData

/// Archiviazione operativa da Controllo scadenze: pulisce la UI chef, conserva audit.
struct ExpiryArchiveService {

    func archive(
        record: TraceabilityRecord,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard !record.isArchived else { return }
        guard record.productStatus != .rejected else {
            throw NSError(
                domain: "ExpiryArchiveService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "I prodotti respinti non si archiviano da qui."]
            )
        }

        record.isArchived = true
        record.archivedAt = Date()
        if record.productStatus == .available || record.productStatus == .expired {
            record.productStatus = .used
        }

        let kind = record.isProductionBatchOutput ? "Produzione consumata" : "Ingrediente terminato"
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .archivedFromExpiryControl,
                operatorName: user.name,
                detail: kind
            )
        )
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: record.restaurantId,
            user: user,
            modelContext: modelContext
        )
    }
}
