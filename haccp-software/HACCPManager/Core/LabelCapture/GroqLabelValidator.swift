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
        case lotMissingLeadingLetter
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
            if lotMissingLeadingLetter(lot: lot, rawContext: rawContext) {
                result.append(.lotMissingLeadingLetter)
            }
        }

        if let expiry {
            let year = Calendar.current.component(.year, from: expiry)
            if year < 1990 || year > 2045 {
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
            case .missingLot, .lotLooksLikeDate, .lotLooksLikeBarcode, .lotTooShort, .lotConflictsWithExpiry, .lotMissingLeadingLetter:
                return true
            default:
                return false
            }
        })
    }

    /// Retry mirato quando il lotto sembra troncato (es. 9330B8 invece di L9330B8).
    static func shouldRetryLotPrecision(_ lot: String?, rawContext: String) -> Bool {
        guard let lot else { return false }
        return lotMissingLeadingLetter(lot: lot, rawContext: rawContext)
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

    private static func lotMissingLeadingLetter(lot: String, rawContext: String) -> Bool {
        guard lot.first?.isNumber == true else { return false }
        let restored = LabelLotSanitizer.restoreLeadingLIfMissing(in: lot, rawContext: rawContext)
        return restored != lot
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
