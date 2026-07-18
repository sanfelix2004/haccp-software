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
        user: LocalUser,
        modelContext: ModelContext
    ) {
        record(
            restaurantId: batch.restaurantId,
            kind: .productionRemovedFromHistory,
            user: user,
            entityType: "ProduzioneBatch",
            entityId: batch.id,
            productionName: batch.productionNameSnapshot,
            lotCode: batch.batchCode,
            summary: "MASTER ha nascosto la produzione dallo storico operativo. Traccia conservata nei documenti. Ingredienti: \(ingredientLines.joined(separator: "; "))",
            detailJSON: encodeJSON([
                "batchId": batch.id.uuidString,
                "batchCode": batch.batchCode,
                "action": "removeFromHistory",
                "ingredients": ingredientLines
            ]),
            modelContext: modelContext
        )
    }

    private static func encodeJSON(_ value: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}
