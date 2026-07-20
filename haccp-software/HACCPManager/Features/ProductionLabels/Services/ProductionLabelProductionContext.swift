import Foundation
import SwiftData

/// Ingrediente / lotto collegato a una produzione etichettata (anche chiuso o nascosto dallo storico UI).
struct ProductionLabelLinkedIngredient: Identifiable, Equatable {
    let id: UUID
    let name: String
    let lotCode: String
    let supplier: String
    let expiryDate: Date?
    let receivedAt: Date?
    let statusLabel: String
    let detailNote: String?
    let isArchivedFromHistory: Bool
    let photoData: Data?
}

/// Contesto produzione completo per scansione QR / scheda etichetta.
struct ProductionLabelProductionContext: Equatable {
    var productionName: String?
    var productionCategory: String?
    var batchCode: String?
    var producedAt: Date?
    var batchOperator: String?
    var batchNotes: String?
    var isBatchArchived: Bool = false
    var outputProductName: String?
    var outputLotCode: String?
    var outputStatusLabel: String?
    var outputExpiryDate: Date?
    var ingredients: [ProductionLabelLinkedIngredient] = []

    var hasProductionInfo: Bool {
        productionName != nil
            || batchCode != nil
            || producedAt != nil
            || outputLotCode != nil
            || !ingredients.isEmpty
    }
}

enum ProductionLabelProductionContextLoader {

    /// Carica produzione + tutti i lotti associati, senza escludere scartati / scaduti / chiusi / soft-hide.
    @MainActor
    static func load(
        for label: ProductionLabelRecord,
        context: ModelContext
    ) -> ProductionLabelProductionContext {
        var result = ProductionLabelProductionContext()
        let rid = label.restaurantId

        if let productionId = label.productionId {
            var prodDesc = FetchDescriptor<Production>(
                predicate: #Predicate { $0.id == productionId }
            )
            prodDesc.fetchLimit = 1
            if let production = try? context.fetch(prodDesc).first {
                result.productionName = production.name
                result.productionCategory = production.categoryNameSnapshot
            }
        }

        let batch = resolveBatch(for: label, context: context)
        if let batch {
            result.batchCode = batch.batchCode
            result.producedAt = batch.producedAt
            result.batchOperator = batch.createdByNameSnapshot
            result.batchNotes = batch.notes
            result.isBatchArchived = batch.isArchived
            if result.productionName == nil || result.productionName?.isEmpty == true {
                result.productionName = batch.productionNameSnapshot
            }
        }

        // Piatto finito collegato all’etichetta.
        if let outputId = label.traceabilityRecordId,
           let output = fetchRecord(id: outputId, context: context) {
            result.outputProductName = output.productName
            result.outputLotCode = output.lotCode.nilIfEmpty
            result.outputStatusLabel = statusLabel(for: output, context: context)
            result.outputExpiryDate = output.expiryDate
        } else if let batch,
                  let output = fetchProductionOutput(batchId: batch.id, restaurantId: rid, context: context) {
            result.outputProductName = output.productName
            result.outputLotCode = output.lotCode.nilIfEmpty
            result.outputStatusLabel = statusLabel(for: output, context: context)
            result.outputExpiryDate = output.expiryDate
        }

        let productionId = label.productionId ?? batch?.productionId
        var ingredientRecords: [TraceabilityRecord] = []
        var seen = Set<UUID>()

        if let productionId {
            let links = ((try? context.fetch(FetchDescriptor<TraceabilityLink>())) ?? [])
                .filter { $0.productionId == productionId }
            for link in links {
                guard !seen.contains(link.receivedItemId),
                      let record = fetchRecord(id: link.receivedItemId, context: context) else { continue }
                // Solo alimenti in ingresso come «associati»; il piatto finito è già sopra.
                if record.isProductionBatchOutput { continue }
                seen.insert(record.id)
                ingredientRecords.append(record)
            }
        }

        if let batch {
            let tracked = ((try? context.fetch(FetchDescriptor<IngredienteTracciato>())) ?? [])
                .filter { $0.produzioneBatchId == batch.id }
                .sorted { $0.sequenceIndex < $1.sequenceIndex }

            for item in tracked {
                if let lot = item.lotCodeExtracted?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty,
                   let match = findRecord(lotCode: lot, restaurantId: rid, context: context),
                   !seen.contains(match.id) {
                    seen.insert(match.id)
                    ingredientRecords.append(match)
                    continue
                }
                // Solo hint OCR senza record: riga sintetica.
                let name = item.ingredientNameAssigned
                    ?? item.ingredientNameHint
                    ?? "Ingrediente"
                let lot = item.lotCodeExtracted?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "—"
                result.ingredients.append(
                    ProductionLabelLinkedIngredient(
                        id: item.id,
                        name: name,
                        lotCode: lot.isEmpty ? "—" : lot,
                        supplier: "—",
                        expiryDate: nil,
                        receivedAt: item.lotRegisteredAt ?? item.createdAt,
                        statusLabel: item.stato.label,
                        detailNote: "Da sessione produzione (foto OCR)",
                        isArchivedFromHistory: false,
                        photoData: nil
                    )
                )
            }
        }

        // Foto disponibili (anche archiviate: risolviamo se presenti).
        let images = ((try? context.fetch(FetchDescriptor<ProductImage>())) ?? [])
        let lottoFotos = ((try? context.fetch(FetchDescriptor<LottoFoto>())) ?? [])
            .filter { $0.restaurantId == rid }

        for record in ingredientRecords.sorted(by: { $0.productName.localizedCaseInsensitiveCompare($1.productName) == .orderedAscending }) {
            let photo = ProductImageBytesResolver.resolve(
                record: record,
                images: images,
                lottoFotos: lottoFotos
            )
            let life = TraceabilityLifecycleSummary.build(record: record, logs: fetchLogs(for: record.id, context: context))
            var detail: String?
            if let closure = life.closure {
                detail = [
                    closure.outcome,
                    closure.occurredAt.formatted(date: .abbreviated, time: .shortened),
                    "da \(closure.operatorName)"
                ].joined(separator: " · ")
                if let note = closure.note, !note.isEmpty {
                    detail = "\(detail!) — \(note)"
                }
            } else if record.isArchived {
                detail = "Nascosto dallo storico operativo (conservato in Documenti)"
            }

            result.ingredients.append(
                ProductionLabelLinkedIngredient(
                    id: record.id,
                    name: record.productName,
                    lotCode: record.lotCode.isEmpty ? "—" : record.lotCode,
                    supplier: record.supplier.isEmpty ? "—" : record.supplier,
                    expiryDate: record.expiryDate,
                    receivedAt: record.receivedAt,
                    statusLabel: statusLabel(for: record, context: context),
                    detailNote: detail,
                    isArchivedFromHistory: record.isArchived,
                    photoData: photo
                )
            )
        }

        if result.productionName == nil {
            result.productionName = label.productName
        }
        if result.productionCategory == nil {
            result.productionCategory = label.category
        }
        if result.batchCode == nil {
            result.batchCode = label.lotCode
        }
        if result.producedAt == nil {
            result.producedAt = label.productionDate
        }
        if result.batchOperator == nil {
            result.batchOperator = label.createdByNameSnapshot
        }

        return result
    }

    // MARK: - Private

    private static func resolveBatch(
        for label: ProductionLabelRecord,
        context: ModelContext
    ) -> ProduzioneBatch? {
        let rid = label.restaurantId
        if let lot = label.lotCode?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
            let batches = ((try? context.fetch(FetchDescriptor<ProduzioneBatch>())) ?? [])
                .filter { $0.restaurantId == rid && $0.batchCode == lot }
            if let exact = batches.first { return exact }
        }
        if let productionId = label.productionId {
            return ((try? context.fetch(FetchDescriptor<ProduzioneBatch>())) ?? [])
                .filter { $0.restaurantId == rid && $0.productionId == productionId }
                .max(by: { $0.producedAt < $1.producedAt })
        }
        if let traceId = label.traceabilityRecordId,
           let record = fetchRecord(id: traceId, context: context),
           let batchId = record.produzioneBatchId {
            var desc = FetchDescriptor<ProduzioneBatch>(predicate: #Predicate { $0.id == batchId })
            desc.fetchLimit = 1
            return try? context.fetch(desc).first
        }
        return nil
    }

    private static func fetchProductionOutput(
        batchId: UUID,
        restaurantId: UUID,
        context: ModelContext
    ) -> TraceabilityRecord? {
        ((try? context.fetch(FetchDescriptor<TraceabilityRecord>())) ?? [])
            .first { $0.restaurantId == restaurantId && $0.produzioneBatchId == batchId }
    }

    private static func fetchRecord(id: UUID, context: ModelContext) -> TraceabilityRecord? {
        var desc = FetchDescriptor<TraceabilityRecord>(predicate: #Predicate { $0.id == id })
        desc.fetchLimit = 1
        return try? context.fetch(desc).first
    }

    private static func findRecord(
        lotCode: String,
        restaurantId: UUID,
        context: ModelContext
    ) -> TraceabilityRecord? {
        ((try? context.fetch(FetchDescriptor<TraceabilityRecord>())) ?? [])
            .first { $0.restaurantId == restaurantId && $0.lotCode == lotCode }
    }

    private static func fetchLogs(for recordId: UUID, context: ModelContext) -> [TraceabilityLog] {
        ((try? context.fetch(FetchDescriptor<TraceabilityLog>())) ?? [])
            .filter { $0.receivedItemId == recordId }
    }

    private static func statusLabel(for record: TraceabilityRecord, context: ModelContext) -> String {
        let life = TraceabilityLifecycleSummary.build(
            record: record,
            logs: fetchLogs(for: record.id, context: context)
        )
        if let closure = life.closure {
            return closure.outcome
        }
        if record.isArchived {
            return "\(record.productStatus.label) · nascosto storico"
        }
        return record.productStatus.label
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
