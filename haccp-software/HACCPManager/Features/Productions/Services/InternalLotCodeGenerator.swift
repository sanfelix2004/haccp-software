import Foundation
import SwiftData

/// Generatore codice lotto interno produzione: `YYYYMMDD-XX`.
enum InternalLotCodeGenerator {
    /// Contatore giornaliero per ristorante (tutte le produzioni dello stesso giorno).
    static func nextCode(
        restaurantId: UUID,
        producedAt: Date = Date(),
        modelContext: ModelContext,
        excludingBatchId: UUID? = nil,
        calendar: Calendar = .current
    ) -> String {
        let dayStart = calendar.startOfDay(for: producedAt)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? producedAt
        let dayKey = dayKeyFormatter.string(from: dayStart)

        let descriptor = FetchDescriptor<ProduzioneBatch>()
        let sameDay = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter {
                $0.restaurantId == restaurantId
                    && $0.producedAt >= dayStart
                    && $0.producedAt < dayEnd
                    && !$0.isArchived
                    && $0.id != excludingBatchId
            }

        var maxSeq = 0
        for batch in sameDay {
            if let seq = parseSequence(from: batch.batchCode, dayKey: dayKey) {
                maxSeq = max(maxSeq, seq)
            } else {
                maxSeq = max(maxSeq, sameDay.count)
            }
        }

        let next = maxSeq + 1
        return String(format: "%@-%02d", dayKey, next)
    }

    static func isInternalLotCode(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: #"^\d{8}-\d{2,}$"#, options: .regularExpression) != nil
    }

    private static func parseSequence(from code: String, dayKey: String) -> Int? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(dayKey + "-") else { return nil }
        let suffix = String(trimmed.dropFirst(dayKey.count + 1))
        return Int(suffix)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd"
        return f
    }()
}
