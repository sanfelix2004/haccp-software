import Foundation

public struct LotNormalizer: Sendable {
    public static func normalize(_ raw: String?, minimumLength: Int = 3) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'#"))
        value = value.replacingOccurrences(of: " ", with: "")
        let upper = value.uppercased()
        if LabelKeywordDictionary.isPackagingNoise(upper) { return nil }
        // Solo lettere = marketing / disclaimer (qualsiasi lunghezza)
        if upper.allSatisfy(\.isLetter) { return nil }
        let minLen = max(2, minimumLength)
        guard value.count >= minLen, value.count <= 28 else { return nil }
        if looksLikeDate(value) { return nil }
        if looksLikeTimeOnly(value) { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./#:()"))
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        if value.allSatisfy(\.isNumber), (12...14).contains(value.count) { return nil }
        // Compatto 6/8 cifre = quasi sempre data, non lotto
        if value.allSatisfy(\.isNumber), value.count == 6 || value.count == 8 {
            if ExpiryFormatParser.parseCompact6(value) != nil
                || ExpiryFormatParser.parseCompact8(value) != nil {
                return nil
            }
        }
        return value
    }

    private static func looksLikeDate(_ value: String) -> Bool {
        let patterns = [
            #"^\d{1,2}[\/\-\.]\d{1,2}([\/\-\.]\d{2,4})?$"#,
            #"^\d{1,2}[\/\-\.]\d{4}$"#,
            #"^\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}$"#
        ]
        return patterns.contains { pattern in
            value.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func looksLikeTimeOnly(_ value: String) -> Bool {
        value.range(of: #"^\d{1,2}:\d{2}(:\d{2})?$"#, options: .regularExpression) != nil
    }
}

public struct ExpirySanityValidator: Sendable {
    public var yearsBack: Int
    public var yearsForward: Int

    public init(yearsBack: Int = 2, yearsForward: Int = 10) {
        self.yearsBack = yearsBack
        self.yearsForward = yearsForward
    }

    public func validate(_ date: Date?, reference: Date = Date()) -> Date? {
        guard let date else { return nil }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let refYear = calendar.component(.year, from: reference)
        guard year >= refYear - yearsBack, year <= refYear + yearsForward else {
            return nil
        }
        return date
    }
}
