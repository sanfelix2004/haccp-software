import Foundation
import SwiftData

/// Scrive movimenti immutabili per Documenti (append-only).
enum DocumentMovementRecorder {

    @discardableResult
    static func record(
        restaurantId: UUID,
        kind: HACCPDocumentMovementKind,
        user: LocalUser,
        entityType: String,
        entityId: UUID,
        productionName: String? = nil,
        lotCode: String? = nil,
        summary: String,
        detailJSON: String? = nil,
        occurredAt: Date = Date(),
        modelContext: ModelContext
    ) -> HACCPDocumentMovement {
        let movement = HACCPDocumentMovement(
            restaurantId: restaurantId,
            kind: kind,
            occurredAt: occurredAt,
            operatorUserId: user.id,
            operatorName: user.name,
            entityType: entityType,
            entityId: entityId,
            productionName: productionName,
            lotCode: lotCode,
            summary: summary,
            detailJSON: detailJSON
        )
        modelContext.insert(movement)
        return movement
    }

    static func recordProductionCompleted(
        batch: ProduzioneBatch,
        ingredientLines: [String],
        user: LocalUser,
        modelContext: ModelContext
    ) {
        let summaryParts = [
            "Lotto produzione \(batch.batchCode)",
            ingredientLines.isEmpty
                ? "Nessun ingrediente elencato"
                : "\(ingredientLines.count) ingredienti: \(ingredientLines.joined(separator: "; "))"
        ]
        record(
            restaurantId: batch.restaurantId,
            kind: .productionCompleted,
            user: user,
            entityType: "ProduzioneBatch",
            entityId: batch.id,
            productionName: batch.productionNameSnapshot,
            lotCode: batch.batchCode,
            summary: summaryParts.joined(separator: " · "),
            detailJSON: encodeJSON([
                "batchId": batch.id.uuidString,
                "batchCode": batch.batchCode,
                "productionId": batch.productionId.uuidString,
                "ingredients": ingredientLines
            ]),
            occurredAt: batch.producedAt,
            modelContext: modelContext
        )
    }

    static func recordProductionRemovedFromHistory(
        batch: ProduzioneBatch,
        ingredientLines: [String],
        reason: HistoryRemovalReason,
        note: String? = nil,
        user: LocalUser,
        modelContext: ModelContext
    ) {
        let reasonDetail = HistoryControlService.auditDetail(reason: reason, note: note)
        record(
            restaurantId: batch.restaurantId,
            kind: .productionRemovedFromHistory,
            user: user,
            entityType: "ProduzioneBatch",
            entityId: batch.id,
            productionName: batch.productionNameSnapshot,
            lotCode: batch.batchCode,
            summary: "MASTER ha nascosto la produzione dallo storico (\(reasonDetail)). Traccia conservata nei documenti. Ingredienti: \(ingredientLines.joined(separator: "; "))",
            detailJSON: encodeRemovalJSON(
                reason: reason,
                note: note,
                extra: [
                    "batchId": batch.id.uuidString,
                    "batchCode": batch.batchCode,
                    "action": "removeFromHistory",
                    "ingredients": ingredientLines
                ]
            ),
            modelContext: modelContext
        )
    }

    static func recordLotClosedFromExpiryControl(
        record closedRecord: TraceabilityRecord,
        outcomeLabel: String,
        note: String? = nil,
        user: LocalUser,
        modelContext: ModelContext
    ) {
        let isProduction = closedRecord.isProductionBatchOutput
        let scope = isProduction ? "Produzione" : "Alimento in ingresso"
        let notePart = (note?.isEmpty == false) ? " — \(note!)" : ""
        let lotLabel = closedRecord.lotCode.isEmpty ? "—" : closedRecord.lotCode
        _ = record(
            restaurantId: closedRecord.restaurantId,
            kind: .lotClosedFromExpiryControl,
            user: user,
            entityType: "TraceabilityRecord",
            entityId: closedRecord.id,
            productionName: closedRecord.productName,
            lotCode: closedRecord.lotCode.nilIfEmpty,
            summary: "\(scope) «\(closedRecord.productName)» · Lotto \(lotLabel) · \(outcomeLabel)\(notePart)",
            detailJSON: encodeJSON([
                "recordId": closedRecord.id.uuidString,
                "productName": closedRecord.productName,
                "lotCode": closedRecord.lotCode,
                "isProduction": isProduction,
                "outcome": outcomeLabel,
                "note": note ?? "",
                "produzioneBatchId": closedRecord.produzioneBatchId?.uuidString ?? ""
            ]),
            modelContext: modelContext
        )
    }

    static func encodeRemovalJSON(
        reason: HistoryRemovalReason,
        note: String?,
        extra: [String: Any] = [:]
    ) -> String? {
        var payload: [String: Any] = extra
        payload["reason"] = reason.rawValue
        payload["reasonLabel"] = reason.auditLabel
        if let note, !note.isEmpty {
            payload["note"] = note
        }
        return encodeJSON(payload)
    }

    static func encodeJSON(_ value: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
