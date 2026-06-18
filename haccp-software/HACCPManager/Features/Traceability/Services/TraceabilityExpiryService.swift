import Foundation
import SwiftData

struct TraceabilityExpiryService {

    func refreshStatuses(
        records: [TraceabilityRecord],
        modelContext: ModelContext,
        now: Date = Date()
    ) -> Int {
        var expiredNow = 0
        for record in records {
            guard ProductExpiryEvaluator.shouldMarkSystemExpired(record, now: now) else { continue }
            record.productStatus = .expired
            modelContext.insert(
                TraceabilityLog(
                    receivedItemId: record.id,
                    actionType: .expired,
                    operatorName: "Sistema"
                )
            )
            expiredNow += 1
        }
        if expiredNow > 0 {
            try? modelContext.save()
        }
        return expiredNow
    }
}
