import Foundation
import SwiftData

struct NonConformitaRicezioneService {
    @discardableResult
    func register(
        ricezione: RicezioneMerce,
        descrizione: String,
        azione: AzioneNonConformita,
        photoDataList: [Data],
        traceRecordId: UUID? = nil,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> NonConformitaRicezione {
        let trimmed = descrizione.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "NonConformitaRicezioneService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Descrizione obbligatoria"])
        }
        guard !photoDataList.isEmpty else {
            throw NSError(domain: "NonConformitaRicezioneService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Almeno una foto obbligatoria"])
        }

        var photoIds: [UUID] = []
        let imageParentId = traceRecordId ?? ricezione.id
        for data in photoDataList {
            guard let compressed = StoredImageCompression.preparedForStorage(data), !compressed.isEmpty else { continue }
            let image = ProductImage(
                receivedItemId: imageParentId,
                imageData: compressed,
                localPath: nil,
                type: .nonComplianceRequired,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name,
                goodsReceiptId: ricezione.id
            )
            modelContext.insert(image)
            photoIds.append(image.id)
        }

        guard !photoIds.isEmpty else {
            throw NSError(domain: "NonConformitaRicezioneService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Impossibile salvare le foto"])
        }

        let nc = NonConformitaRicezione(
            ricezioneMerceId: ricezione.id,
            restaurantId: ricezione.restaurantId,
            descrizione: trimmed,
            azione: azione,
            photoIds: photoIds,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(nc)
        return nc
    }

    func resolve(
        nc: NonConformitaRicezione,
        ricezione: RicezioneMerce?,
        resolvedByName: String,
        modelContext: ModelContext
    ) throws {
        nc.resolvedAt = Date()
        nc.resolvedByNameSnapshot = resolvedByName
        ricezione?.nonComplianceResolvedAt = nc.resolvedAt
        ricezione?.nonComplianceResolvedByNameSnapshot = resolvedByName
        try modelContext.save()
    }
}
