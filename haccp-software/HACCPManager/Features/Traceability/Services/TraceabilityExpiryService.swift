import Foundation
import SwiftData

struct TraceabilityExpiryService {
    func refreshStatuses(
        records: [TraceabilityRecord],
        modelContext: ModelContext
    ) -> Int {
        let now = Date()
        var expiredNow = 0
        for record in records {
            guard record.productStatus != .rejected else { continue }
            guard let expiryDate = record.expiryDate, expiryDate < now else { continue }
            if record.productStatus != .expired {
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
        }
        if expiredNow > 0 {
            try? modelContext.save()
        }
        return expiredNow
    }
}
