import Foundation
import SwiftData

/// Dati lotto/scadenza opzionali in ricezione conforme.
struct RicezioneLotTraceInput {
    var pendingCapture: PendingLottoCapture?
    var manualLotCode: String = ""
    var expiryDate: Date?
    var expiryFromLabel: Bool = false
    var expiryUserEdited: Bool = false
    var acceptedDespiteExpired: Bool = false

    var hasLotOrExpiry: Bool {
        if pendingCapture != nil { return true }
        let lot = manualLotCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return !lot.isEmpty || expiryDate != nil
    }
}

/// Collega Ricezione merci → TraceabilityRecord + Controllo scadenze.
struct RicezioneTraceabilityBridge {
    private let lottoService = LottoFotoService()
    private let expiryTracking = ExpiryTrackingService()

    @discardableResult
    func syncAfterIntake(
        receipt: RicezioneMerce,
        product: ProductTemplate,
        supplier: Supplier,
        hasAnomaly: Bool,
        anomalyDescription: String,
        lotTrace: RicezioneLotTraceInput?,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> TraceabilityRecord? {
        if hasAnomaly {
            let record = try createRejectedRecord(
                receipt: receipt,
                product: product,
                supplierName: supplier.name,
                note: anomalyDescription,
                photoData: receipt.photoData,
                user: user,
                modelContext: modelContext
            )
            mirrorReceiptFields(receipt: receipt, from: record)
            return record
        }

        guard let lotTrace, lotTrace.hasLotOrExpiry else { return nil }

        if let pending = lotTrace.pendingCapture, !pending.photoData.isEmpty {
            var capture = pending
            if capture.lotDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                capture.lotDraft = lotTrace.manualLotCode
            }
            let lotto = try lottoService.confirmCaptureFromReceipt(
                pending: capture,
                template: product,
                supplier: supplier.name,
                expiryDate: lotTrace.expiryDate,
                expiryFromLabel: lotTrace.expiryFromLabel,
                expiryUserEdited: lotTrace.expiryUserEdited,
                acceptedDespiteExpired: lotTrace.acceptedDespiteExpired,
                receipt: receipt,
                user: user,
                modelContext: modelContext
            )
            guard let record = lottoService.traceabilityRecord(for: lotto, modelContext: modelContext) else {
                return nil
            }
            mirrorReceiptFields(receipt: receipt, from: record)
            return record
        }

        let lotCode = lotTrace.manualLotCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = lotCode.isEmpty ? nil : LabelLotSanitizer.validateLot(lotCode)
        let record = try createConformingRecord(
            receipt: receipt,
            product: product,
            supplierName: supplier.name,
            lotCode: sanitized ?? lotCode,
            expiryDate: lotTrace.expiryDate,
            expiryFromLabel: lotTrace.expiryFromLabel,
            expiryUserEdited: lotTrace.expiryUserEdited,
            acceptedDespiteExpired: lotTrace.acceptedDespiteExpired,
            user: user,
            modelContext: modelContext
        )
        mirrorReceiptFields(receipt: receipt, from: record)
        return record
    }

    // MARK: - Private

    private func createRejectedRecord(
        receipt: RicezioneMerce,
        product: ProductTemplate,
        supplierName: String,
        note: String,
        photoData: Data? = nil,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> TraceabilityRecord {
        let record = TraceabilityRecord(
            restaurantId: receipt.restaurantId,
            productName: product.name,
            lotCode: "",
            supplier: supplierName,
            source: .receipt,
            goodsReceiptId: receipt.id,
            receivedAt: receipt.receivedAt,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: note.nilIfEmpty,
            operatorSignature: user.name
        )
        record.categoryRaw = product.category.rawValue
        record.goodsReceiptStatusRaw = receipt.statusRaw
        record.productStatus = ProductStatus.rejected
        record.isNonCompliant = true
        record.nonComplianceNote = note.nilIfEmpty
        record.nonComplianceCorrectiveAction = receipt.correctiveAction
        if let photoData, !photoData.isEmpty {
            record.photoData = photoData
        }
        modelContext.insert(record)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .created,
                operatorName: user.name,
                detail: "Ricezione non conforme"
            )
        )
        return record
    }

    private func createConformingRecord(
        receipt: RicezioneMerce,
        product: ProductTemplate,
        supplierName: String,
        lotCode: String,
        expiryDate: Date?,
        expiryFromLabel: Bool,
        expiryUserEdited: Bool,
        acceptedDespiteExpired: Bool,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> TraceabilityRecord {
        let normalizedExpiry = expiryDate.map { HACCPDateNormalizer.normalizedExpiry($0) }
        let record = TraceabilityRecord(
            restaurantId: receipt.restaurantId,
            productName: product.name,
            lotCode: lotCode,
            supplier: supplierName,
            source: .receipt,
            goodsReceiptId: receipt.id,
            receivedAt: receipt.receivedAt,
            expiryDate: normalizedExpiry,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            operatorSignature: user.name
        )
        record.categoryRaw = product.category.rawValue
        record.goodsReceiptStatusRaw = receipt.statusRaw
        modelContext.insert(record)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .created,
                operatorName: user.name,
                detail: "Ricezione merci conforme"
            )
        )
        if let normalizedExpiry {
            let source = ExpiryTrackingService.resolveIncomingSource(
                expiryFromLabel: expiryFromLabel,
                expiryUserEdited: expiryUserEdited
            )
            try expiryTracking.registerIncomingExpiry(
                on: record,
                expiryDate: normalizedExpiry,
                source: source,
                operatorName: user.name,
                modelContext: modelContext,
                acceptedDespiteExpired: acceptedDespiteExpired
            )
        }
        return record
    }

    private func mirrorReceiptFields(receipt: RicezioneMerce, from record: TraceabilityRecord) {
        if !record.lotCode.isEmpty {
            receipt.lotNumber = record.lotCode
        }
        receipt.expiryDate = record.expiryDate
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
