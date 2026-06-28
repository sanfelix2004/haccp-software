import Foundation
import SwiftData

struct GoodsReceivingService {
    let requirementService = GoodsReceiptRequirementService()
    let validationService = GoodsReceiptValidationService()

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
        let requirement = requirementService.makeRequirement(for: product)
        let validation = validationService.validate(
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
            throw NSError(domain: "GoodsReceivingService", code: 1001, userInfo: [NSLocalizedDescriptionKey: validation.message ?? "Compilazione incompleta"])
        }

        let hasNonOk = validation.hasNonCompliance
        let hasChecklistNotOk = checklistResults.contains { $0.value == .notOk }
        let status: GoodsReceiptStatus = {
            guard hasNonOk else { return .conforme }
            if hasChecklistNotOk { return .nonConforme }
            return .acceptedWithNotes
        }()
        let tempStatus: GoodsReceiptStatus = validation.temperatureOutOfRange ? .acceptedWithNotes : .conforme

        let storedPhoto = hasNonOk
            ? StoredImageCompression.preparedForStorage(photoData)
            : nil

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
            temperatureStatus: tempStatus,
            lotNumber: lotCode,
            expiryDate: expiryDate,
            productionDate: productionDate,
            quantity: quantity,
            unit: unit,
            checklistResultsData: try? JSONEncoder().encode(checklistResults),
            photoData: storedPhoto,
            notes: notes,
            correctiveAction: correctiveAction,
            status: status,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(receipt)
        if hasNonOk,
           let compressed = storedPhoto,
           !compressed.isEmpty {
            modelContext.insert(
                ProductImage(
                    receivedItemId: receipt.id,
                    imageData: compressed,
                    localPath: nil,
                    type: .nonComplianceRequired,
                    createdByUserId: user.id,
                    createdByNameSnapshot: user.name
                )
            )
        }
        try modelContext.save()
        HACCPArchiveSyncCoordinator.requestDeferredSync(
            restaurantId: restaurantId,
            user: user,
            modelContext: modelContext
        )
    }
}
