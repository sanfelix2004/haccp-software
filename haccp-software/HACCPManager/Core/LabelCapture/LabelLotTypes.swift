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
    /// Pulisce prefissi comuni e scarta falsi positivi (EAN, date, rumore).
    static func clean(_ raw: String) -> String {
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .replacingOccurrences(of: " ", with: "")

        // L6036BH099, L52400V757 — la L fa parte del codice, non è un'etichetta
        if value.range(of: #"^[Ll][A-Z0-9]{2,}$"#, options: .regularExpression) != nil {
            return value
        }

        // L.6036BH099 / L:6036 → L6036BH099 (rimuovi solo il separatore dopo L)
        if let regex = try? NSRegularExpression(pattern: #"^[Ll][:.]([A-Z0-9].*)$"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           match.numberOfRanges > 1,
           let codeRange = Range(match.range(at: 1), in: value) {
            return "L" + String(value[codeRange])
        }

        let prefixPatterns = [
            #"(?i)^(?:lot(?:to)?|batch|partita)\s*[:#.]?\s*"#,
            #"(?i)^cod\.?\s*[:#]?\s*"#,
            #"(?i)^(?:mfg|prod|conf)\.?\s*"#
        ]
        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range, in: value) {
                value = String(value[range.upperBound...])
                break
            }
        }

        return value
    }

    static func validateLot(_ raw: String?, rawContext: String = "") -> String? {
        guard let raw else { return nil }
        let cleaned = clean(raw)
        guard !cleaned.isEmpty, cleaned.lowercased() != "null" else { return nil }
        let context = rawContext.isEmpty ? raw : rawContext
        let normalized = restoreLeadingLIfMissing(in: cleaned, rawContext: context)
        guard !isConsumerBarcode(normalized) else { return nil }
        guard !looksLikeDate(normalized) else { return nil }
        guard !looksLikeISODate(normalized) else { return nil }
        guard !looksLikeCompactDateDigits(normalized) else { return nil }
        guard normalized.count >= 3, normalized.count <= 24 else { return nil }
        return refineAmbiguousLotCharacters(normalized)
    }

    /// Se Groq omette la L ma era presente nel testo grezzo (L6036BH099), ripristinala.
    static func restoreLeadingLIfMissing(in lot: String, rawContext: String) -> String {
        guard let first = lot.first, first.isNumber else { return lot }
        let candidates = ["L\(lot)", "l\(lot)"]
        for candidate in candidates {
            if rawContext.contains(candidate) {
                return "L" + lot
            }
        }
        return lot
    }

    /// Corregge confusioni tipiche su stampa a matrice (Y↔V, O↔0, I↔1).
    static func refineAmbiguousLotCharacters(_ lot: String) -> String {
        var value = lot

        if let regex = try? NSRegularExpression(pattern: #"^\d{4,7}Y\d{2,5}$"#),
           regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil {
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
        return regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
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
            return regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        }
    }

    static func looksLikeISODate(_ value: String) -> Bool {
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
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
