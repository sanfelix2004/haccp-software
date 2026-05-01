import Foundation
import SwiftData

struct TraceabilityService {
    func addRecord(
        restaurantId: UUID,
        productName: String,
        lotCode: String,
        supplier: String,
        receivedAt: Date,
        expiryDate: Date?,
        productionReference: String?,
        photoData: Data?,
        user: LocalUser,
        notes: String?,
        modelContext: ModelContext
    ) throws -> TraceabilityRecord {
        let trimmedProduct = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduct.isEmpty else {
            throw NSError(
                domain: "TraceabilityService",
                code: 4001,
                userInfo: [NSLocalizedDescriptionKey: "Il nome prodotto e obbligatorio."]
            )
        }

        let record = TraceabilityRecord(
            restaurantId: restaurantId,
            productName: trimmedProduct,
            lotCode: lotCode.trimmingCharacters(in: .whitespacesAndNewlines),
            supplier: supplier.trimmingCharacters(in: .whitespacesAndNewlines),
            receivedAt: receivedAt,
            expiryDate: expiryDate,
            productionReference: productionReference?.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            operatorSignature: user.name
        )
        modelContext.insert(record)
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .created,
                operatorName: user.name
            )
        )
        try modelContext.save()
        return record
    }

    func markNonCompliant(
        record: TraceabilityRecord,
        note: String,
        correctiveAction: String,
        imageData: Data,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            throw NSError(domain: "TraceabilityService", code: 4002, userInfo: [NSLocalizedDescriptionKey: "Inserisci il motivo della non conformità."])
        }
        guard !trimmedAction.isEmpty else {
            throw NSError(domain: "TraceabilityService", code: 4003, userInfo: [NSLocalizedDescriptionKey: "Inserisci l'azione correttiva obbligatoria."])
        }
        guard imageData.isEmpty == false else {
            throw NSError(domain: "TraceabilityService", code: 4004, userInfo: [NSLocalizedDescriptionKey: "Per una non conformità è obbligatorio allegare una foto."])
        }

        record.isNonCompliant = true
        record.nonComplianceNote = trimmedNote
        record.nonComplianceCorrectiveAction = trimmedAction
        record.productStatus = .rejected
        modelContext.insert(
            TraceabilityLog(
                receivedItemId: record.id,
                actionType: .nonCompliance,
                operatorName: user.name
            )
        )
        modelContext.insert(
            ProductImage(
                receivedItemId: record.id,
                imageData: imageData,
                localPath: nil,
                type: .nonComplianceRequired,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
        )
        try modelContext.save()
    }

    func markUsed(
        record: TraceabilityRecord,
        modelContext: ModelContext
    ) throws {
        record.productStatus = .used
        try modelContext.save()
    }

    func deleteRecord(
        record: TraceabilityRecord,
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        modelContext: ModelContext
    ) throws {
        links.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
        logs.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
        images.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
        modelContext.delete(record)
        try modelContext.save()
    }

    /// Elimina la voce di tracciabilità e, se presente, la ricezione merci collegata (`goodsReceiptId`). Nessun record orfano.
    func deleteTraceabilityEntry(
        record: TraceabilityRecord,
        goodsReceipts: [GoodsReceipt],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        modelContext: ModelContext
    ) throws {
        links.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
        logs.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
        images.filter { $0.receivedItemId == record.id }.forEach { modelContext.delete($0) }
        if let gid = record.goodsReceiptId,
           let receipt = goodsReceipts.first(where: { $0.id == gid }) {
            modelContext.delete(receipt)
        }
        modelContext.delete(record)
        try modelContext.save()
    }

    func addImage(
        to record: TraceabilityRecord,
        imageData: Data,
        type: ProductImageType,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        modelContext.insert(
            ProductImage(
                receivedItemId: record.id,
                imageData: imageData,
                localPath: nil,
                type: type,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
        )
        try modelContext.save()
    }

    func exportTraceabilityReport(
        records: [TraceabilityRecord],
        links: [TraceabilityLink],
        productions: [Production]
    ) -> String {
        let productionMap = Dictionary(uniqueKeysWithValues: productions.map { ($0.id, $0.name) })
        let header = "prodotto,fornitore,lotto,stato,data_ricezione,data_scadenza,produzioni"
        let rows = records.map { record in
            let linkedNames = links
                .filter { $0.receivedItemId == record.id }
                .compactMap { productionMap[$0.productionId] }
                .joined(separator: " | ")
            return [
                csvCell(record.productName),
                csvCell(record.supplier),
                csvCell(record.lotCode),
                csvCell(record.productStatus.label),
                csvCell(record.receivedAt.formatted(date: .abbreviated, time: .shortened)),
                csvCell(record.expiryDate?.formatted(date: .abbreviated, time: .omitted) ?? ""),
                csvCell(linkedNames)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func csvCell(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
