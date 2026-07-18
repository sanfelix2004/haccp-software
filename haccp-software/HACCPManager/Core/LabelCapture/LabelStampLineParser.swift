import Foundation

/// Parser locale per righe di stampa produzione (matrice su sfondo scuro, data+orario, lotto).
enum LabelStampLineParser {

    /// Estrae lotto da righe di stampa a matrice (es. `L9330 B8 00:09`, `L6036BH099`, `15701 00:44`).
    static func extractLot(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let patterns: [(String, ([String]) -> String?)] = [
            // Yogurt / stampigliatura getto: "08:18H-FYB" (orario + codice linea)
            (
                #"(?i)\b(\d{1,2}:\d{2}H-[A-Z0-9]{2,12})\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\b(\d{1,2}:\d{2}[A-Z][A-Z0-9]*-[A-Z0-9]{1,12})\b"#,
                { groups in groups.first }
            ),
            // GS1 AI (10) lotto — `-` in fondo alla classe (ICU rifiuta `\-./`).
            (
                #"(?i)\(10\)\s*([0-9A-Z][0-9A-Z./_#:-]{2,22})"#,
                { groups in groups.first }
            ),
            // "Batch number: 44464" / "Lot number 12345" — non catturare la parola "number".
            (
                #"(?i)\b(?:batch|lot(?:to)?)\s*(?:number|no\.?|nr\.?|#)\s*[:.=]?\s*([0-9A-Z][0-9A-Z./_#:-]{1,22})\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\b(?:numero\s*(?:di\s*)?lotto|cod(?:ice)?\s*lotto)\s*[:.=]?\s*([0-9A-Z][0-9A-Z./_#:-]{1,22})\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\bLOT\s*[:=]?\s*(?:#)?([0-9A-Z][0-9A-Z./_#:-]{2,22})\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\b(?:lot(?:to)?|batch|partita|b\.?\s*n\.?|cod\.?\s*lotto|n[°o]\.?|nr\.?)\s*[:#.=]?\s*((?:#)?[0-9A-Z][0-9A-Z./_#:-]{2,22})\b"#,
                { groups in groups.first }
            ),
            (
                // Stamp industriale: "240526 14:32 4B22" → lotto 4B22 (non la data)
                #"(?i)\b\d{6}\s+\d{1,2}:\d{2}(?::\d{2})?\s+([A-Z0-9]{2,12})\b"#,
                { groups in groups.first }
            ),
            (
                // Dopo data GG/MM/AA: "31/08/26\n08:18H-FYB" o stessa riga
                #"(?i)\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\s+(\d{1,2}:\d{2}H-[A-Z0-9]{2,12})\b"#,
                { groups in groups.first }
            ),
            (
                // Latte / stamp: "15701 00:44" → lotto 15701 (orario produzione ignorato)
                #"(?i)\b(\d{4,8})\s+\d{1,2}:\d{2}(?::\d{2})?\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\b(\d{6,12}[A-Z0-9]{1,4}-\d{2})(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\bL(\d{3,6})\s+([A-Z0-9]{1,6})(?:\s+\d{1,2}:\d{2})?\b"#,
                { groups in
                    guard groups.count == 2 else { return nil }
                    return "L\(groups[0])\(groups[1])"
                }
            ),
            (
                #"(?i)\bL[.:]\s*([A-Z0-9][A-Z0-9\-./_]{2,20})\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\bL([A-Z0-9]{4,18})\b"#,
                { groups in
                    guard let code = groups.first else { return nil }
                    return "L\(code)"
                }
            ),
            (
                // Alfanumerico generico vicino a orario di produzione
                #"(?i)\b([A-Z]\d{3,10}[A-Z0-9]{0,8}|\d{3,8}[A-Z]{1,4}\d{0,6})\s+\d{1,2}:\d{2}\b"#,
                { groups in groups.first }
            ),
            (
                #"(?i)\b([A-Z0-9]{2,6}[-_/][A-Z0-9]{2,10})\b"#,
                { groups in groups.first }
            )
        ]

        for (pattern, build) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range),
                  match.numberOfRanges > 1 else { continue }

            var groups: [String] = []
            for index in 1..<match.numberOfRanges {
                guard let groupRange = Range(match.range(at: index), in: trimmed) else { continue }
                groups.append(String(trimmed[groupRange]))
            }
            if let lot = build(groups),
               let validated = LabelLotSanitizer.validateExtractedCandidate(lot, rawContext: trimmed) {
                return validated
            }
        }

        return nil
    }

    /// Estrae scadenza da righe tipo `SELL BY 09/02`, `BEST BEFORE 31 AUG 2018`.
    static func parseExpiry(from text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if LabelLotSanitizer.looksLikeTimeOnly(trimmed) { return nil }

        if let sellBy = ExpiryDateParser.parseSellByCompact(from: trimmed) { return sellBy }
        if let industrial = parseIndustrialCompactStamp(trimmed) { return industrial }
        if let stamp = parseDateWithTrailingTime(trimmed) { return stamp }
        if let compact = parseCompactDateDigits(trimmed) { return compact }

        return ExpiryDateParser.parse(from: trimmed)
    }

    /// `240526 14:32 4B22` → scadenza 24/05/2026 (GGMMAA implicito).
    private static func parseIndustrialCompactStamp(_ text: String) -> Date? {
        let pattern = #"\b(\d{6})\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s+[A-Z0-9]{2,12})?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return parseCompactDateDigits(String(text[range]))
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
        // "23/08/2026 06:08" oppure "31/08/26 08:18H-FYB" (lotto dopo la data, stessa riga)
        let patterns = [
            #"(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s|$)"#,
            #"(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\s+\d{1,2}:\d{2}[A-Z0-9\-]+"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  match.numberOfRanges >= 4,
                  let dRange = Range(match.range(at: 1), in: text),
                  let mRange = Range(match.range(at: 2), in: text),
                  let yRange = Range(match.range(at: 3), in: text),
                  let day = Int(text[dRange]),
                  let month = Int(text[mRange]),
                  let rawYear = Int(text[yRange]) else { continue }

            let year = rawYear < 100
                ? ExpiryDateParser.expandTwoDigitYear(rawYear)
                : rawYear
            if let date = makeDate(day: day, month: month, year: year) {
                return date
            }
        }
        return nil
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

        if digits.count == 8 {
            if let y = Int(digits.prefix(4)), (2000...2045).contains(y),
               let month = Int(digits.dropFirst(4).prefix(2)),
               let day = Int(digits.suffix(2)) {
                return makeDate(day: day, month: month, year: y)
            }
            if let day = Int(digits.prefix(2)),
               let month = Int(digits.dropFirst(2).prefix(2)),
               let year = Int(digits.suffix(4)) {
                return makeDate(day: day, month: month, year: year)
            }
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
