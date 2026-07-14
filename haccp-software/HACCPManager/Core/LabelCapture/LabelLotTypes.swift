import Foundation

struct LabelLotExtractionResult: Sendable {
    let rawText: String
    let extractedIngredient: String?
    let extractedLotCode: String?
    let extractedExpiryDate: Date?
    let confidence: Double
    let auditLines: [String]
}

protocol LabelLotExtractorProtocol: Sendable {
    func analyzeLabel(from imageData: Data, expectedIngredients: [String]) async throws -> LabelLotExtractionResult
}

enum LabelLotError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Immagine non valida per la lettura del lotto."
        }
    }
}

enum LabelLotSanitizer {
    private static let quoteCharacters = CharacterSet(charactersIn: "\"'")

    private static let reservedLotTokens: Set<String> = [
        "SELL", "BY", "BEST", "BEFORE", "LOT", "LOTT", "LOTTO", "EXP", "EXPIRY",
        "TMC", "BB", "USE", "SCAD", "SCADE", "SCADENZA", "ENTRO", "NULL"
    ]

    /// Pulisce prefissi comuni e scarta falsi positivi (EAN, date, rumore).
    static func clean(_ raw: String) -> String {
        var value = String(raw)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.trimmingCharacters(in: quoteCharacters)
        value.removeAll { $0 == " " || $0 == "\u{00A0}" }

        // L6184 (Julian) → 6184
        if let regex = try? NSRegularExpression(pattern: #"^[Ll](\d{3,5})$"#),
           let match = regex.firstMatch(in: value, range: nsRange(for: value)),
           match.numberOfRanges > 1,
           let codeRange = Range(match.range(at: 1), in: value) {
            return String(value[codeRange])
        }

        // L6036BH099, L52400V757 — L fa parte del codice alfanumerico
        if value.range(of: #"^[Ll][A-Z0-9]{2,}$"#, options: .regularExpression) != nil,
           value.dropFirst().contains(where: { $0.isLetter }) {
            return value
        }

        // L.24056 / L:24056 → 24056 (prefisso separato, no lettere nel corpo)
        if let regex = try? NSRegularExpression(pattern: #"^[Ll][:.]([A-Z0-9].*)$"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: value, range: nsRange(for: value)),
           match.numberOfRanges > 1,
           let codeRange = Range(match.range(at: 1), in: value) {
            return String(value[codeRange])
        }

        let prefixPatterns = [
            #"(?i)^(?:lot(?:to)?|batch|partita)\s*[:#.]?\s*"#,
            #"(?i)^cod\.?\s*[:#]?\s*"#,
            #"(?i)^(?:mfg|prod|conf)\.?\s*"#
        ]
        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: value, range: nsRange(for: value)),
               let range = Range(match.range, in: value) {
                value = String(value[range.upperBound...])
                break
            }
        }

        return value
    }

    /// Validazione completa (OCR / Groq).
    static func validateLot(_ raw: String?, rawContext: String = "") -> String? {
        validateCandidate(raw, rawContext: rawContext, restoreLeadingL: true)
    }

    /// Validazione per candidati estratti da regex — evita ricorsione con `extractLot`.
    static func validateExtractedCandidate(_ raw: String, rawContext: String = "") -> String? {
        validateCandidate(raw, rawContext: rawContext, restoreLeadingL: true)
    }

    private static func validateCandidate(
        _ raw: String?,
        rawContext: String,
        restoreLeadingL: Bool
    ) -> String? {
        guard let raw else { return nil }
        let cleaned = clean(raw)
        guard !cleaned.isEmpty, cleaned.lowercased() != "null" else { return nil }
        guard !isReservedLotToken(cleaned) else { return nil }
        let context = rawContext.isEmpty ? raw : rawContext
        let normalized = restoreLeadingL
            ? restoreLeadingLIfMissing(in: cleaned, rawContext: context)
            : cleaned
        guard !isConsumerBarcode(normalized) else { return nil }
        guard !looksLikeDate(normalized) else { return nil }
        guard !looksLikeISODate(normalized) else { return nil }
        guard !looksLikeCompactDateDigits(normalized) else { return nil }
        guard normalized.count >= 3, normalized.count <= 24 else { return nil }
        return refineAmbiguousLotCharacters(normalized)
    }

    private static func nsRange(for string: String) -> NSRange {
        NSRange(string.startIndex..<string.endIndex, in: string)
    }

    private static func isReservedLotToken(_ value: String) -> Bool {
        let upper = value.uppercased()
        if reservedLotTokens.contains(upper) { return true }
        if upper.hasPrefix("SELL") || upper.hasPrefix("BEST") { return true }
        return false
    }

    /// Se Groq omette la L ma era presente nel testo grezzo (L6036BH099, L9330 B8), ripristinala.
    static func restoreLeadingLIfMissing(in lot: String, rawContext: String) -> String {
        guard let first = lot.first, first.isNumber else { return lot }

        let candidates = ["L\(lot)", "l\(lot)"]
        for candidate in candidates {
            if rawContext.range(of: candidate, options: .caseInsensitive) != nil {
                return "L" + lot
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"(?i)\bL(\d{3,6})\s+([A-Z0-9]{1,6})\b"#),
           let match = regex.firstMatch(in: rawContext, range: nsRange(for: rawContext)),
           match.numberOfRanges >= 3,
           let numRange = Range(match.range(at: 1), in: rawContext),
           let suffixRange = Range(match.range(at: 2), in: rawContext) {
            let combined = "\(rawContext[numRange])\(rawContext[suffixRange])"
            if lot.caseInsensitiveCompare(combined) == .orderedSame {
                return "L" + lot
            }
        }

        return lot
    }

    /// Corregge confusioni tipiche su stampa a matrice (Y↔V, O↔0, I↔1).
    static func refineAmbiguousLotCharacters(_ lot: String) -> String {
        var value = lot

        if let regex = try? NSRegularExpression(pattern: #"^\d{4,7}Y\d{2,5}$"#),
           regex.firstMatch(in: value, range: nsRange(for: value)) != nil {
            value = value.replacingOccurrences(of: "Y", with: "V")
        }

        if value.contains("O"), value.filter(\.isNumber).count >= 4 {
            value = value.replacingOccurrences(
                of: #"(?<=\d)O(?=\d)"#,
                with: "0",
                options: .regularExpression
            )
        }

        if value.contains("I"), value.filter(\.isNumber).count >= 4 {
            value = value.replacingOccurrences(
                of: #"(?<=\d)I(?=\d)"#,
                with: "1",
                options: .regularExpression
            )
        }

        return value
    }

    static func looksLikeTimeOnly(_ value: String) -> Bool {
        let pattern = #"^\d{1,2}:\d{2}(:\d{2})?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: value, range: nsRange(for: value)) != nil
    }

    static func validateExpiry(_ date: Date?) -> Date? {
        guard let date else { return nil }
        let year = Calendar.current.component(.year, from: date)
        guard year >= 2000, year <= 2045 else { return nil }
        return date
    }

    static func isConsumerBarcode(_ value: String) -> Bool {
        let digits = value.filter(\.isNumber)
        guard digits.count == value.count else { return false }
        return digits.count >= 12 && digits.count <= 14
    }

    static func looksLikeDate(_ value: String) -> Bool {
        let patterns = [
            #"^\d{1,2}[\/\-\.]\d{1,2}([\/\-\.]\d{2,4})?$"#,
            #"^\d{1,2}[\/\-\.]\d{4}$"#,
            #"^\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}$"#
        ]
        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(in: value, range: nsRange(for: value)) != nil
        }
    }

    static func looksLikeISODate(_ value: String) -> Bool {
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: value, range: nsRange(for: value)) != nil
    }

    /// Scarta stringhe numeriche tipo YYMMDD o DDMMYY spesso scambiate col lotto.
    static func looksLikeCompactDateDigits(_ value: String) -> Bool {
        guard value.count == 6, value.allSatisfy(\.isNumber) else { return false }
        guard let a = Int(value.prefix(2)),
              let b = Int(value.dropFirst(2).prefix(2)),
              let c = Int(value.suffix(2)) else { return false }
        let asDDMMYY = (1...31).contains(a) && (1...12).contains(b)
        let asYYMMDD = (1...12).contains(b) && (1...31).contains(c)
        return asDDMMYY || asYYMMDD
    }
}
