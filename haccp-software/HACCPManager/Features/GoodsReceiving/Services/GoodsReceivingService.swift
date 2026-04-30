import Foundation
import SwiftData

struct GoodsReceivingService {
    let requirementService = GoodsReceiptRequirementService()
    let validationService = GoodsReceiptValidationService()
    let traceabilityService = GoodsReceiptTraceabilityService()

    func ensureDefaults(
        restaurantId: UUID,
        suppliers: [Supplier],
        templates: [ProductTemplate],
        modelContext: ModelContext
    ) {
        if templates.filter({ $0.restaurantId == restaurantId }).isEmpty {
            let defaults: [ProductTemplate] = [
                .init(restaurantId: restaurantId, name: "Carni fresche", category: .freshMeat, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
                .init(restaurantId: restaurantId, name: "Pesce fresco", category: .freshFish, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresAppearanceCheck: true),
                .init(restaurantId: restaurantId, name: "Uova", category: .refrigerated, defaultMinTemp: 0, defaultMaxTemp: 10, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
                .init(restaurantId: restaurantId, name: "Verdura e frutta", category: .produce, requiresAppearanceCheck: true, requiresMoldCheck: true, requiresFreshnessCheck: true),
                .init(restaurantId: restaurantId, name: "Prodotti secchi", category: .dryProducts, requiresExpiry: true),
                .init(restaurantId: restaurantId, name: "Prodotti surgelati", category: .frozenProducts, defaultMaxTemp: -18, requiresTemperature: true, requiresLot: true, requiresExpiry: true, requiresThawingCheck: true),
                .init(restaurantId: restaurantId, name: "Alimenti misti (pronti)", category: .combined, defaultMinTemp: 0, defaultMaxTemp: 4, requiresTemperature: true, requiresLot: true, requiresExpiry: true),
                .init(restaurantId: restaurantId, name: "Prodotti confezionati", category: .packaged, requiresLot: true, requiresExpiry: true)
            ]
            defaults.forEach { modelContext.insert($0) }
        }
        try? modelContext.save()
    }

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
            correctiveAction: correctiveAction ?? ""
        )
        guard validation.canSubmit else {
            throw NSError(domain: "GoodsReceivingService", code: 1001, userInfo: [NSLocalizedDescriptionKey: validation.message ?? "Compilazione incompleta"])
        }

        let hasNonOk = checklistResults.contains { $0.value == .notOk } || validation.temperatureOutOfRange
        let status: GoodsReceiptStatus = hasNonOk ? ((notes ?? "").isEmpty && (correctiveAction ?? "").isEmpty ? .nonConforme : .acceptedWithNotes) : .conforme
        let tempStatus: GoodsReceiptStatus = validation.temperatureOutOfRange ? .acceptedWithNotes : .conforme

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
            photoData: photoData,
            notes: notes,
            correctiveAction: correctiveAction,
            status: status,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(receipt)
        traceabilityService.createTraceabilityItem(receipt: receipt, modelContext: modelContext)
        try modelContext.save()
    }
}
