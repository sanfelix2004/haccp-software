//
//  ProductionLabelsService.swift
//  CRUD, duplicazione, collegamenti moduli HACCP.
//

import Foundation
import SwiftData

struct ProductionLabelsService {

    func create(
        draft: ProductionLabelDraft,
        restaurantId: UUID,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> ProductionLabelRecord {
        let name = draft.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw labelError("Il nome prodotto è obbligatorio.")
        }
        guard draft.expiryDate >= draft.productionDate else {
            throw labelError("La scadenza deve essere successiva alla produzione.")
        }

        if ProductionLabelLinkMatcher.hasSourceLink(draft) {
            var descriptor = FetchDescriptor<ProductionLabelRecord>(
                predicate: #Predicate { $0.restaurantId == restaurantId }
            )
            let existing = try modelContext.fetch(descriptor)
            if let conflict = ProductionLabelLinkMatcher.existingLabel(for: draft, in: existing) {
                throw labelError(
                    "Esiste già un'etichetta per «\(conflict.productName)». Apri l'etichetta esistente per ristampare."
                )
            }
        }

        let quantity = Double(draft.quantity.replacingOccurrences(of: ",", with: "."))

        var record = ProductionLabelRecord(
            restaurantId: restaurantId,
            productName: name,
            productionDate: draft.productionDate,
            expiryDate: draft.expiryDate,
            lotCode: draft.lotCode.nilIfEmpty,
            previewText: nil,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: draft.notes.nilIfEmpty,
            operatorSignature: user.name,
            category: draft.category.nilIfEmpty,
            supplier: draft.supplier.nilIfEmpty,
            allergens: draft.allergens.nilIfEmpty,
            storageInstructions: draft.storageInstructions.nilIfEmpty,
            temperatureNote: draft.temperatureNote.nilIfEmpty,
            quantity: quantity,
            unit: draft.unit.nilIfEmpty,
            productStatus: draft.productStatus,
            sourceModule: draft.sourceModule,
            traceabilityRecordId: draft.traceabilityRecordId,
            goodsReceiptId: draft.goodsReceiptId,
            blastChillingRecordId: draft.blastChillingRecordId,
            defrostRecordId: draft.defrostRecordId,
            productionId: draft.productionId,
            status: .active
        )
        record.previewText = buildPreviewText(record)
        assignQRPayload(to: record, modelContext: modelContext)
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    func update(
        _ label: ProductionLabelRecord,
        draft: ProductionLabelDraft,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let name = draft.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw labelError("Il nome prodotto è obbligatorio.") }

        label.productName = name
        label.productionDate = draft.productionDate
        label.expiryDate = draft.expiryDate
        label.lotCode = draft.lotCode.nilIfEmpty
        label.category = draft.category.nilIfEmpty
        label.supplier = draft.supplier.nilIfEmpty
        label.allergens = draft.allergens.nilIfEmpty
        label.storageInstructions = draft.storageInstructions.nilIfEmpty
        label.temperatureNote = draft.temperatureNote.nilIfEmpty
        label.quantity = Double(draft.quantity.replacingOccurrences(of: ",", with: "."))
        label.unit = draft.unit.nilIfEmpty
        label.notes = draft.notes.nilIfEmpty
        label.productStatus = draft.productStatus
        label.updatedAt = Date()
        label.previewText = buildPreviewText(label)
        assignQRPayload(to: label, modelContext: modelContext)
        try modelContext.save()
    }

    func duplicate(
        _ label: ProductionLabelRecord,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> ProductionLabelRecord {
        var copy = ProductionLabelRecord(
            restaurantId: label.restaurantId,
            productName: label.productName,
            productionDate: Date(),
            expiryDate: label.expiryDate,
            lotCode: label.lotCode,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: label.notes,
            operatorSignature: user.name,
            category: label.category,
            supplier: label.supplier,
            allergens: label.allergens,
            storageInstructions: label.storageInstructions,
            temperatureNote: label.temperatureNote,
            quantity: label.quantity,
            unit: label.unit,
            productStatus: label.productStatus,
            sourceModule: label.sourceModule,
            traceabilityRecordId: label.traceabilityRecordId,
            goodsReceiptId: label.goodsReceiptId,
            blastChillingRecordId: label.blastChillingRecordId,
            defrostRecordId: label.defrostRecordId,
            productionId: label.productionId,
            duplicateOfLabelId: label.id
        )
        copy.previewText = buildPreviewText(copy)
        assignQRPayload(to: copy, modelContext: modelContext)
        modelContext.insert(copy)
        try modelContext.save()
        return copy
    }

    func markReprinted(_ label: ProductionLabelRecord, modelContext: ModelContext) throws {
        label.reprintCount += 1
        label.labelStatus = .reprinted
        label.updatedAt = Date()
        try modelContext.save()
    }

    func archive(_ label: ProductionLabelRecord, modelContext: ModelContext) throws {
        label.isArchived = true
        label.archivedAt = Date()
        label.updatedAt = Date()
        try modelContext.save()
    }

    // MARK: - Draft da moduli collegati

    func draft(from trace: TraceabilityRecord) -> ProductionLabelDraft {
        var d = ProductionLabelDraft()
        d.productName = trace.productName
        d.lotCode = trace.lotCode
        d.supplier = trace.supplier
        d.productionDate = trace.receivedAt
        d.expiryDate = trace.expiryDate ?? trace.receivedAt
        d.sourceModule = .traceability
        d.traceabilityRecordId = trace.id
        d.goodsReceiptId = trace.goodsReceiptId
        return d
    }

    /// Preferire `draft(from: TraceabilityRecord)` — ogni ricezione crea un lotto in tracciabilità.
    func draft(from receipt: GoodsReceivingRecord, traceabilityRecordId: UUID? = nil) -> ProductionLabelDraft {
        var d = ProductionLabelDraft()
        d.productName = receipt.productNameSnapshot
        d.lotCode = receipt.lotNumber ?? ""
        d.supplier = receipt.supplierNameSnapshot
        d.productionDate = receipt.productionDate ?? receipt.receivedAt
        d.expiryDate = receipt.expiryDate ?? Calendar.current.date(byAdding: .day, value: 3, to: receipt.receivedAt) ?? receipt.receivedAt
        d.quantity = receipt.quantity.map { String($0) } ?? ""
        d.unit = receipt.unit ?? "pz"
        d.temperatureNote = receipt.temperatureValue.map { String(format: "%.1f °C", $0) } ?? ""
        d.sourceModule = .traceability
        d.goodsReceiptId = receipt.id
        d.traceabilityRecordId = traceabilityRecordId
        return d
    }

    func draft(from blast: BlastChillingRecord) -> ProductionLabelDraft {
        var d = ProductionLabelDraft()
        d.productName = blast.productionNameSnapshot
        d.category = blast.productionCategorySnapshot
        d.productionDate = blast.endedAt ?? blast.startedAt
        d.expiryDate = Calendar.current.date(byAdding: .day, value: 90, to: d.productionDate) ?? d.productionDate
        d.temperatureNote = blast.finalTemperature.map { String(format: "%.1f °C", $0) } ?? ""
        d.storageInstructions = "Surgelato -18°C"
        d.productStatus = .blastChilled
        d.sourceModule = .blastChilling
        d.blastChillingRecordId = blast.id
        d.productionId = blast.productionId
        return d
    }

    func draft(from defrost: DefrostRecord) -> ProductionLabelDraft {
        var d = ProductionLabelDraft()
        d.productName = defrost.productName
        d.lotCode = defrost.lotNumber ?? ""
        d.productionDate = defrost.endAt ?? defrost.startAt
        d.expiryDate = Calendar.current.date(byAdding: .hour, value: 24, to: d.productionDate) ?? d.productionDate
        d.storageInstructions = "Frigo +2°C / +4°C — consumare entro 24h"
        d.productStatus = .defrosted
        d.sourceModule = .defrost
        d.defrostRecordId = defrost.id
        d.traceabilityRecordId = defrost.traceabilityItemId
        return d
    }

    func draft(from production: Production) -> ProductionLabelDraft {
        var d = ProductionLabelDraft()
        d.productName = production.name
        d.sourceModule = .production
        d.productionId = production.id
        return d
    }

    func draft(from label: ProductionLabelRecord) -> ProductionLabelDraft {
        var d = ProductionLabelDraft()
        d.productName = label.productName
        d.category = label.category ?? ""
        d.lotCode = label.lotCode ?? ""
        d.supplier = label.supplier ?? ""
        d.productionDate = label.productionDate
        d.expiryDate = label.expiryDate
        d.allergens = label.allergens ?? ""
        d.storageInstructions = label.storageInstructions ?? ""
        d.temperatureNote = label.temperatureNote ?? ""
        d.quantity = label.quantity.map { String($0) } ?? ""
        d.unit = label.unit ?? "pz"
        d.notes = label.notes ?? ""
        d.productStatus = label.productStatus
        d.sourceModule = label.sourceModule
        d.traceabilityRecordId = label.traceabilityRecordId
        d.goodsReceiptId = label.goodsReceiptId
        d.blastChillingRecordId = label.blastChillingRecordId
        d.defrostRecordId = label.defrostRecordId
        d.productionId = label.productionId
        return d
    }

    private func assignQRPayload(to label: ProductionLabelRecord, modelContext: ModelContext) {
        let restaurantName = fetchRestaurantName(label.restaurantId, modelContext: modelContext)
        label.qrPayload = ProductionLabelQRService.buildPayload(for: label, restaurantName: restaurantName)
    }

    private func fetchRestaurantName(_ id: UUID, modelContext: ModelContext) -> String? {
        var descriptor = FetchDescriptor<Restaurant>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.name
    }

    private func buildPreviewText(_ label: ProductionLabelRecord) -> String {
        [
            label.productName,
            label.lotCode.map { "Lotto \($0)" },
            "Scad. \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))"
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func labelError(_ message: String) -> NSError {
        NSError(domain: "ProductionLabelsService", code: 4200, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
