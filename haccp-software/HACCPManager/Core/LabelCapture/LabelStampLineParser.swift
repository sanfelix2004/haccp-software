import Foundation

/// Parser locale per righe di stampa produzione (matrice su sfondo scuro, data+orario, lotto).
enum LabelStampLineParser {

    /// Estrae la data da righe tipo `23/08/2026 06:08` — ignora l'orario.
    static func parseExpiry(from text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if LabelLotSanitizer.looksLikeTimeOnly(trimmed) { return nil }

        if let stamp = parseDateWithTrailingTime(trimmed) { return stamp }
        if let compact = parseCompactDateDigits(trimmed) { return compact }

        return nil
    }

    /// Rileva scadenze derivate per errore dall'orario di produzione (es. 06:08 → 6/8/2026).
    static func expiryMatchesMisreadProductionTime(expiry: Date, context: String) -> Bool {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: expiry)
        let month = calendar.component(.month, from: expiry)

        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2}):(\d{2})\b"#) else { return false }
        let range = NSRange(context.startIndex..., in: context)
        var found = false
        regex.enumerateMatches(in: context, range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 3,
                  let hRange = Range(match.range(at: 1), in: context),
                  let mRange = Range(match.range(at: 2), in: context),
                  let hour = Int(context[hRange]),
                  let minute = Int(context[mRange]) else { return }
            if (day == hour && month == minute) || (day == minute && month == hour) {
                found = true
            }
        }
        return found
    }

    private static func parseDateWithTrailingTime(_ text: String) -> Date? {
        let pattern = #"^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\s+\d{1,2}:\d{2}\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 4,
              let dRange = Range(match.range(at: 1), in: text),
              let mRange = Range(match.range(at: 2), in: text),
              let yRange = Range(match.range(at: 3), in: text),
              let day = Int(text[dRange]),
              let month = Int(text[mRange]),
              let rawYear = Int(text[yRange]) else { return nil }

        let year = rawYear < 100
            ? ExpiryDateParser.expandTwoDigitYear(rawYear)
            : rawYear
        return makeDate(day: day, month: month, year: year)
    }

    /// Formato compatto DDMMYY o DDMMYYYY (es. 230826, 23082026).
    private static func parseCompactDateDigits(_ text: String) -> Date? {
        let digits = text.filter(\.isNumber)
        guard digits == text else { return nil }

        if digits.count == 6,
           let day = Int(digits.prefix(2)),
           let month = Int(digits.dropFirst(2).prefix(2)),
           let yy = Int(digits.suffix(2)) {
            return makeDate(day: day, month: month, year: ExpiryDateParser.expandTwoDigitYear(yy))
        }

        if digits.count == 8,
           let day = Int(digits.prefix(2)),
           let month = Int(digits.dropFirst(2).prefix(2)),
           let year = Int(digits.suffix(4)) {
            return makeDate(day: day, month: month, year: year)
        }

        return nil
    }

    private static func makeDate(day: Int, month: Int, year: Int) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month), year >= 2000, year <= 2045 else { return nil }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        guard let date = Calendar.current.date(from: components) else { return nil }
        return HACCPDateNormalizer.normalizedExpiry(date)
    }
}
