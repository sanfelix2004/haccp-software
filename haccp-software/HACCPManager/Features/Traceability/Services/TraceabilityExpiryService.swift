import Foundation
import SwiftData

struct TraceabilityExpiryService {

    func refreshStatuses(
        records: [TraceabilityRecord],
        modelContext: ModelContext,
        now: Date = Date()
    ) -> Int {
        let recordIds = Set(records.map(\.id))
        let withdrawnIds = withdrawnRecordIds(from: modelContext, recordIds: recordIds)
        var changed = 0

        for record in records {
            if record.productStatus == .used {
                guard withdrawnIds.contains(record.id) == false,
                      let expiryDate = record.expiryDate,
                      ProductExpiryEvaluator.isExpiredByDate(expiryDate, now: now) else { continue }
                record.productStatus = .expired
                modelContext.insert(
                    TraceabilityLog(
                        receivedItemId: record.id,
                        actionType: .expired,
                        operatorName: "Sistema"
                    )
                )
                changed += 1
                continue
            }

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
            try? modelContext.save()
        }
        return changed
    }

    private func withdrawnRecordIds(
        from modelContext: ModelContext,
        recordIds: Set<UUID>
    ) -> Set<UUID> {
        guard !recordIds.isEmpty else { return [] }
        let logs = (try? modelContext.fetch(FetchDescriptor<TraceabilityLog>())) ?? []
        return Set(
            logs.compactMap { log in
                guard log.actionType == .withdrawn, recordIds.contains(log.receivedItemId) else { return nil }
                return log.receivedItemId
            }
        )
    }
}
