import Foundation
import SwiftData

struct TraceabilityExpiryService {

    func refreshStatuses(
        records: [TraceabilityRecord],
        modelContext: ModelContext,
        now: Date = Date()
    ) -> Int {
        var changed = 0

        for record in records {
            // Stati terminali: non ri-promuovere a scaduto (es. lotto già consumato).
            guard record.productStatus != .used,
                  record.productStatus != .rejected else { continue }

            guard ProductExpiryEvaluator.shouldMarkSystemExpired(record, now: now) else { continue }
            record.productStatus = .expired
            modelContext.insert(
                TraceabilityLog(
                    receivedItemId: record.id,
                    actionType: .expired,
                    operatorName: "Sistema"
                )
            )
            changed += 1
        }
        if changed > 0 {
            modelContext.saveSafely(operation: "traceability-expiry-refresh")
        }
        return changed
    }
}
