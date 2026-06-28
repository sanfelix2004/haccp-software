import Foundation

/// Validazione post-estrazione e trigger retry mirati (zero token se OK).
enum GroqLabelValidator {

    enum Issue: Equatable {
        case missingLot
        case missingExpiry
        case lotLooksLikeDate
        case lotLooksLikeBarcode
        case lotTooShort
        case expiryUnreasonable
        case expiryLooksLikeProductionTime
        case lotConflictsWithExpiry
    }

    static func issues(lot: String?, expiry: Date?, rawContext: String = "") -> [Issue] {
        var result: [Issue] = []
        if lot == nil { result.append(.missingLot) }
        if expiry == nil { result.append(.missingExpiry) }

        if let lot {
            if LabelLotSanitizer.looksLikeDate(lot) || LabelLotSanitizer.looksLikeISODate(lot) {
                result.append(.lotLooksLikeDate)
            }
            if LabelLotSanitizer.isConsumerBarcode(lot) {
                result.append(.lotLooksLikeBarcode)
            }
            if lot.count < 3 {
                result.append(.lotTooShort)
            }
        }

        if let expiry {
            let year = Calendar.current.component(.year, from: expiry)
            if year < 2000 || year > 2045 {
                result.append(.expiryUnreasonable)
            }
            let today = Calendar.current.startOfDay(for: Date())
            if expiry < Calendar.current.date(byAdding: .year, value: -2, to: today)! {
                result.append(.expiryUnreasonable)
            }
            if !rawContext.isEmpty,
               LabelStampLineParser.expiryMatchesMisreadProductionTime(expiry: expiry, context: rawContext) {
                result.append(.expiryLooksLikeProductionTime)
            }
        }

        if let lot, let expiry, lotConflicts(lot: lot, expiry: expiry) {
            result.append(.lotConflictsWithExpiry)
        }

        return result
    }

    static func shouldRetryLot(_ issues: [Issue]) -> Bool {
        issues.contains(where: {
            switch $0 {
            case .missingLot, .lotLooksLikeDate, .lotLooksLikeBarcode, .lotTooShort, .lotConflictsWithExpiry:
                return true
            default:
                return false
            }
        })
    }

    static func shouldRetryExpiry(_ issues: [Issue]) -> Bool {
        issues.contains(where: {
            switch $0 {
            case .missingExpiry, .expiryUnreasonable, .expiryLooksLikeProductionTime, .lotConflictsWithExpiry:
                return true
            default:
                return false
            }
        })
    }

    static func shouldVerify(_ issues: [Issue], lot: String?, expiry: Date?) -> Bool {
        guard lot != nil, expiry != nil else { return false }
        return !issues.isEmpty
    }

    private static func lotConflicts(lot: String, expiry: Date) -> Bool {
        let cleaned = LabelLotSanitizer.clean(lot)
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.day, .month, .year], from: expiry)
        guard let day = parts.day, let month = parts.month, let year = parts.year else { return false }

        let dd = String(format: "%02d", day)
        let mm = String(format: "%02d", month)
        let yy = String(format: "%02d", year % 100)
        let yyyy = String(year)

        let fragments = [
            "\(dd)\(mm)\(yy)", "\(dd)\(mm)\(yyyy.suffix(2))",
            "\(mm)\(yyyy)", "\(mm)/\(yyyy)", "\(dd)/\(mm)/\(yy)",
            "\(dd).\(mm).\(yy)", "\(yyyy)-\(mm)-\(dd)"
        ]
        return fragments.contains { cleaned.caseInsensitiveCompare($0) == .orderedSame }
            || cleaned.contains("\(mm)\(yyyy)")
    }
}
