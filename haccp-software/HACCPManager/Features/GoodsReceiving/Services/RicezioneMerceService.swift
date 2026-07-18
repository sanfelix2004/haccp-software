import Foundation
import SwiftData

struct RicezioneMerceValidationOutcome {
    let canSubmit: Bool
    let message: String?
}

struct RicezioneMerceService {
    private let ncService = NonConformitaRicezioneService()
    private let traceabilityBridge = RicezioneTraceabilityBridge()

    func validateIntake(
        supplierName: String,
        merchandiseDescription: String,
        hasAnomaly: Bool,
        anomalyDescription: String,
        anomalyPhotos: [Data],
        anomalyAction: AzioneNonConformita?
    ) -> RicezioneMerceValidationOutcome {
        if supplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(canSubmit: false, message: "Seleziona o inserisci un fornitore.")
        }
        if merchandiseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(canSubmit: false, message: "Inserisci la descrizione della merce.")
        }
        if hasAnomaly {
            if anomalyDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .init(canSubmit: false, message: "Descrivi l'anomalia riscontrata.")
            }
            if anomalyPhotos.isEmpty {
                return .init(canSubmit: false, message: "Allega almeno una foto dell'anomalia.")
            }
            if anomalyAction == nil {
                return .init(canSubmit: false, message: "Seleziona l'azione intrapresa (scartata o resa al fornitore).")
            }
        }
        return .init(canSubmit: true, message: nil)
    }

    @discardableResult
    func saveIntake(
        restaurantId: UUID,
        supplier: Supplier,
        product: ProductTemplate,
        receivedAt: Date = Date(),
        hasAnomaly: Bool,
        anomalyDescription: String,
        anomalyPhotos: [Data],
        anomalyAction: AzioneNonConformita?,
        lotTrace: RicezioneLotTraceInput? = nil,
        acceptedDespiteExpired: Bool = false,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> RicezioneMerce {
        let validation = validateIntake(
            supplierName: supplier.name,
            merchandiseDescription: product.name,
            hasAnomaly: hasAnomaly,
            anomalyDescription: anomalyDescription,
            anomalyPhotos: anomalyPhotos,
            anomalyAction: anomalyAction
        )
        guard validation.canSubmit else {
            throw NSError(
                domain: "RicezioneMerceService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: validation.message ?? "Dati incompleti"]
            )
        }

        let receipt = RicezioneMerce(
            restaurantId: restaurantId,
            supplierId: supplier.id,
            supplierNameSnapshot: supplier.name,
            productTemplateId: product.id,
            productNameSnapshot: product.name,
            category: product.category,
            receivedAt: receivedAt,
            status: hasAnomaly ? .nonConforme : .conforme,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(receipt)

        if hasAnomaly, let firstPhoto = anomalyPhotos.first {
            receipt.photoData = StoredImageCompression.preparedForStorage(firstPhoto)
        }

        if hasAnomaly, let azione = anomalyAction {
            receipt.notes = anomalyDescription
            receipt.correctiveAction = azione.label
        }

        var lotInput = lotTrace
        lotInput?.acceptedDespiteExpired = acceptedDespiteExpired
        let traceRecord = try traceabilityBridge.syncAfterIntake(
            receipt: receipt,
            product: product,
            supplier: supplier,
            hasAnomaly: hasAnomaly,
            anomalyDescription: anomalyDescription,
            lotTrace: lotInput,
            user: user,
            modelContext: modelContext
        )

        if hasAnomaly, let azione = anomalyAction {
            _ = try ncService.register(
                ricezione: receipt,
                descrizione: anomalyDescription,
                azione: azione,
                photoDataList: anomalyPhotos,
                traceRecordId: traceRecord?.id,
                user: user,
                modelContext: modelContext
            )
            // Garantisce foto anche sul record tracciabilità (storico + documenti).
            if let traceRecord, (traceRecord.photoData == nil || traceRecord.photoData?.isEmpty == true),
               let first = anomalyPhotos.first.flatMap({ StoredImageCompression.preparedForStorage($0) }) {
                traceRecord.photoData = first
            }
        }

        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
        return receipt
    }
}
