import Foundation
import SwiftData

// MARK: - GoodsReceivingService
// Logica di business per la ricezione merci.
// Responsabilità: validazione, costruzione del record, persistenza, trigger documenti.
// NON gestisce lo stato UI — comunica i risultati tramite throws.

struct GoodsReceivingService {

    // MARK: - Dependencies (iniettate, testabili)

    let requirementService: GoodsReceiptRequirementService
    let validationService: GoodsReceiptValidationService

    init(
        requirementService: GoodsReceiptRequirementService = GoodsReceiptRequirementService(),
        validationService: GoodsReceiptValidationService = GoodsReceiptValidationService()
    ) {
        self.requirementService = requirementService
        self.validationService  = validationService
    }

    // MARK: - Save

    /// Valida e salva una nuova ricevuta di ricezione merce.
    /// Lancia se la validazione fallisce o il salvataggio non riesce.
    ///
    /// - Note: Chiama anche i trigger per aggiornamento asincrono dei documenti PDF mensili.
    func saveReceipt(
        restaurantId: UUID,
        supplier: Supplier,
        product: ProductTemplate,
        receivedAt: Date,
        temperature: Double?,
        lotCode: String?,
        expiryDate: Date?,
        productionDate: Date?,
        quantity: Double?,
        unit: String?,
        checklistResults: [GoodsReceiptChecklistResult],
        photoData: Data?,
        notes: String?,
        correctiveAction: String?,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {

        // MARK: 1. Validazione

        let requirement = requirementService.makeRequirement(for: product)
        let validation  = validationService.validate(
            requirement: requirement,
            checklistResults: checklistResults,
            temperatureValue: temperature,
            lotNumber: lotCode ?? "",
            hasExpiryDate: expiryDate != nil,
            notes: notes ?? "",
            correctiveAction: correctiveAction ?? "",
            photoData: photoData,
            enforcePhotoIfNonCompliant: true
        )
        guard validation.canSubmit else {
            throw GoodsReceivingError.validationFailed(validation.message ?? "Compilazione incompleta")
        }

        // MARK: 2. Determinazione stato conformità

        let hasNonCompliance     = validation.hasNonCompliance
        let hasChecklistFailure  = checklistResults.contains { $0.value == .notOk }
        let overallStatus: GoodsReceiptStatus = {
            guard hasNonCompliance else { return .conforme }
            return hasChecklistFailure ? .nonConforme : .acceptedWithNotes
        }()
        let temperatureStatus: GoodsReceiptStatus = validation.temperatureOutOfRange
            ? .acceptedWithNotes : .conforme

        // BUG FIX: la foto viene compressa e salvata solo in caso di non conformità.
        // In caso conforme, non si spreca memoria.
        let storedPhoto: Data? = hasNonCompliance
            ? StoredImageCompression.preparedForStorage(photoData)
            : nil

        // MARK: 3. Costruzione e inserimento record

        let receipt = GoodsReceipt(
            restaurantId: restaurantId,
            supplierId: supplier.id,
            supplierNameSnapshot: supplier.name,
            productTemplateId: product.id,
            productNameSnapshot: product.name,
            category: product.category,
            receivedAt: receivedAt,
            temperatureValue: temperature,
            minAllowed: requirement.defaultMinTemp,
            maxAllowed: requirement.defaultMaxTemp,
            temperatureStatus: temperatureStatus,
            lotNumber: lotCode,
            expiryDate: expiryDate,
            productionDate: productionDate,
            quantity: quantity,
            unit: unit,
            checklistResultsData: try? JSONEncoder().encode(checklistResults),
            photoData: storedPhoto,
            notes: notes,
            correctiveAction: correctiveAction,
            status: overallStatus,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(receipt)

        // Salva la foto separata come ProductImage solo se è in caso di non conformità
        // E la foto è effettivamente presente (prevenzione di ProductImage vuoti).
        if hasNonCompliance, let compressed = storedPhoto, !compressed.isEmpty {
            let productImage = ProductImage(
                receivedItemId: receipt.id,
                imageData: compressed,
                localPath: nil,
                type: .nonComplianceRequired,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(productImage)
        }

        // MARK: 4. Persistenza

        try modelContext.save()

        // MARK: 5. Trigger aggiornamento documenti mensili (asincroni, non bloccanti)

        // Sync rapido (8s debounce) per sincronizzazione iCloud.
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
        // Ricalcolo PDF mensili (45s debounce) — compila progressivamente il documento del mese.
        MonthlyDocumentUpdateTrigger.shared.notifyDataChanged(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
    }
}

// MARK: - GoodsReceivingError

enum GoodsReceivingError: LocalizedError {
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .validationFailed(let msg): return msg
        }
    }
}
