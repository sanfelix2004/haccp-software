import Foundation
import SwiftData

/// Registro centrale scadenze HACCP: collega tracciabilità ↔ Controllo scadenze con audit.
struct ExpiryTrackingService {

    // MARK: - Ingresso merci (camera / lotto foto)

    /// Registra o aggiorna la scadenza su un `TraceabilityRecord` di ingresso.
    @discardableResult
    func registerIncomingExpiry(
        on record: TraceabilityRecord,
        expiryDate: Date,
        source: ExpirySource,
        operatorName: String,
        modelContext: ModelContext,
        acceptedDespiteExpired: Bool = false
    ) throws -> TraceabilityRecord {
        if ProductExpiryEvaluator.isExpiredByDate(expiryDate), !acceptedDespiteExpired {
            throw ExpiryTrackingError.expiredProductRequiresAcknowledgment
        }

        record.expiryDate = HACCPDateNormalizer.normalizedExpiry(expiryDate)
        record.expirySource = source

        appendAuditLog(
            recordId: record.id,
            source: source,
            expiryDate: expiryDate,
            operatorName: operatorName,
            acceptedDespiteExpired: acceptedDespiteExpired,
            modelContext: modelContext
        )
        return record
    }

    /// Risolve la provenienza scadenza da flag UI / lotto foto.
    static func resolveIncomingSource(
        expiryFromLabel: Bool,
        expiryUserEdited: Bool
    ) -> ExpirySource {
        if expiryFromLabel && !expiryUserEdited { return .groqLabel }
        return .manualOperator
    }

    // MARK: - Produzione (piatto finito)

    /// Crea o aggiorna il record in Controllo scadenze per un batch di produzione completato.
    @discardableResult
    func registerProductionExpiry(
        batch: ProduzioneBatch,
        production: Production,
        expiryDate: Date,
        shelfLifeDays: Int?,
        constraint: ScadenzaCalculator.ProductionExpiryConstraint? = nil,
        forcedCatalogDuration: Bool = false,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> TraceabilityRecord {
        let constraintSuffix = productionExpiryAuditSuffix(
            constraint: constraint,
            forcedCatalogDuration: forcedCatalogDuration
        )
        if let existing = productionRecord(for: batch.id, modelContext: modelContext) {
            existing.expiryDate = HACCPDateNormalizer.normalizedExpiry(expiryDate)
            existing.expirySource = .productionShelfLife
            appendAuditLog(
                recordId: existing.id,
                source: .productionShelfLife,
                expiryDate: expiryDate,
                operatorName: user.name,
                acceptedDespiteExpired: false,
                detailSuffix: (shelfLifeDays.map { " · \($0) gg" } ?? "") + constraintSuffix,
                modelContext: modelContext
            )
            return existing
        }

        let record = TraceabilityRecord(
            restaurantId: batch.restaurantId,
            productName: production.name,
            lotCode: batch.batchCode,
            supplier: "Produzione interna",
            receivedAt: batch.producedAt,
            expiryDate: HACCPDateNormalizer.normalizedExpiry(expiryDate),
            productionReference: production.name,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            operatorSignature: user.name
        )
        record.produzioneBatchId = batch.id
        record.expirySource = .productionShelfLife
        if !production.categoryNameSnapshot.isEmpty {
            record.categoryRaw = production.categoryNameSnapshot
        }
        modelContext.insert(record)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                productionId: production.id,
                actionType: .created,
                operatorName: user.name,
                detail: "Lotto produzione \(batch.batchCode)"
            )
        )
        appendAuditLog(
            recordId: record.id,
            source: .productionShelfLife,
            expiryDate: expiryDate,
            operatorName: user.name,
            acceptedDespiteExpired: false,
            detailSuffix: (shelfLifeDays.map { " · \($0) gg" } ?? "") + constraintSuffix,
            modelContext: modelContext
        )
        return record
    }

    private func productionExpiryAuditSuffix(
        constraint: ScadenzaCalculator.ProductionExpiryConstraint?,
        forcedCatalogDuration: Bool
    ) -> String {
        guard let constraint else { return "" }
        if forcedCatalogDuration {
            return " · durata catalogo forzata (cottura)"
        }
        if constraint.isIngredientLimited, let name = constraint.limitingIngredientName {
            return " · vincolo ingrediente: \(name)"
        }
        return ""
    }

    // MARK: - Private

    private func productionRecord(for batchId: UUID, modelContext: ModelContext) -> TraceabilityRecord? {
        let descriptor = FetchDescriptor<TraceabilityRecord>()
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .first { $0.produzioneBatchId == batchId && !$0.isArchived }
    }

    private func appendAuditLog(
        recordId: UUID,
        source: ExpirySource,
        expiryDate: Date,
        operatorName: String,
        acceptedDespiteExpired: Bool,
        detailSuffix: String = "",
        modelContext: ModelContext
    ) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .short
        var detail = "\(source.auditLabel) · scadenza \(formatter.string(from: expiryDate))"
        if acceptedDespiteExpired {
            detail += " · ACCETTATO NONOSTANTE SCADUTO (conferma operatore)"
        }
        detail += detailSuffix

        modelContext.insert(
            TraceabilityLog(
                receivedItemId: recordId,
                actionType: .expiryRegistered,
                operatorName: operatorName,
                detail: detail
            )
        )
    }
}
