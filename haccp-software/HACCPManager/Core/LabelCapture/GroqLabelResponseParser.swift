import Foundation

/// Parsing e validazione locale della risposta Groq (zero token extra).
enum GroqLabelResponseParser {
    struct Parsed: Sendable {
        var lot: String?
        var expiry: Date?
        var rawPayload: String
        var audit: [String]

        var isComplete: Bool { lot != nil && expiry != nil }

        func merging(_ other: Parsed) -> Parsed {
            Parsed(
                lot: preferredLot(lot, other.lot),
                expiry: preferredExpiry(expiry, other.expiry),
                rawPayload: mergedPayload(rawPayload, other.rawPayload),
                audit: audit + other.audit
            )
        }

        private func preferredLot(_ a: String?, _ b: String?) -> String? {
            guard let a else { return b }
            guard let b else { return a }
            let issuesA = GroqLabelValidator.issues(lot: a, expiry: expiry, rawContext: rawPayload)
            let issuesB = GroqLabelValidator.issues(lot: b, expiry: expiry, rawContext: rawPayload)
            if issuesA.contains(.lotLooksLikeDate) && !issuesB.contains(.lotLooksLikeDate) { return b }
            if issuesB.contains(.lotLooksLikeDate) && !issuesA.contains(.lotLooksLikeDate) { return a }
            return a.count >= b.count ? a : b
        }

        private func preferredExpiry(_ a: Date?, _ b: Date?) -> Date? {
            guard let a else { return b }
            guard let b else { return a }
            let issuesA = GroqLabelValidator.issues(lot: lot, expiry: a, rawContext: rawPayload)
            let issuesB = GroqLabelValidator.issues(lot: lot, expiry: b, rawContext: rawPayload)
            if issuesA.contains(.expiryLooksLikeProductionTime) && !issuesB.contains(.expiryLooksLikeProductionTime) {
                return b
            }
            return a
        }

        private func mergedPayload(_ a: String, _ b: String) -> String {
            if b.isEmpty { return a }
            if a.isEmpty { return b }
            return a + "\n---\n" + b
        }
    }

    static func parse(_ jsonString: String) -> Parsed {
        var audit: [String] = []
        let payload = sanitizePayload(jsonString)

        var lot: String?
        var expiry: Date?
        var expiryRaw: String?

        if let dict = jsonDictionary(from: payload) {
            lot = extractLot(from: dict)
            expiryRaw = extractExpiryRaw(from: dict)
        }

        if lot == nil {
            lot = extractLotRegex(from: payload)
            if lot != nil { audit.append("Lotto da estrazione JSON parziale") }
        }

        if let expiryRaw, !expiryRaw.isEmpty {
            if let stamp = LabelStampLineParser.parseExpiry(from: expiryRaw) {
                expiry = stamp
                audit.append("Scadenza da riga data+orario")
            } else {
                expiry = parseExpiryString(expiryRaw)
                if expiry != nil { audit.append("Scadenza normalizzata") }
            }
        }

        lot = lot.flatMap { LabelLotSanitizer.validateLot($0, rawContext: payload) }

        var validatedExpiry: Date? = expiry
        if let candidate = validatedExpiry {
            if GroqLabelValidator.issues(lot: lot, expiry: candidate, rawContext: payload)
                .contains(.expiryLooksLikeProductionTime) {
                validatedExpiry = nil
                audit.append("Scadenza scartata: probabile orario produzione")
            } else {
                validatedExpiry = LabelLotSanitizer.validateExpiry(candidate)
            }
        }
        expiry = validatedExpiry

        if let lot {
            audit.append("Lotto: «\(lot)»")
        } else {
            audit.append("Lotto non trovato o non valido")
        }
        if let expiry {
            audit.append("Scadenza: \(formatItalian(expiry))")
        } else {
            audit.append("Scadenza non trovata o non valida")
        }

        return Parsed(lot: lot, expiry: expiry, rawPayload: payload, audit: audit)
    }

    static func confidence(for parsed: Parsed) -> Double {
        let issues = GroqLabelValidator.issues(
            lot: parsed.lot,
            expiry: parsed.expiry,
            rawContext: parsed.rawPayload
        )
        var score: Double
        switch (parsed.lot != nil, parsed.expiry != nil) {
        case (true, true): score = 0.92
        case (true, false): score = 0.72
        case (false, true): score = 0.68
        case (false, false): score = 0
        }
        if issues.contains(.lotLooksLikeDate) { score -= 0.35 }
        if issues.contains(.lotLooksLikeBarcode) { score -= 0.30 }
        if issues.contains(.expiryUnreasonable) { score -= 0.25 }
        if issues.contains(.expiryLooksLikeProductionTime) { score -= 0.40 }
        if issues.contains(.lotConflictsWithExpiry) { score -= 0.20 }
        return max(0, min(1, score))
    }

    // MARK: - JSON

    private static func sanitizePayload(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func jsonDictionary(from payload: String) -> [String: Any]? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else { return nil }
        return dict
    }

    private static let lotKeys = [
        "lotto", "l", "lot", "lotcode", "lot_code", "batch", "partita", "codice", "codice_lotto"
    ]
    private static let expiryKeys = [
        "scadenza", "e", "exp", "expiry", "expirydate", "expiry_date", "tmc", "data", "data_scadenza"
    ]

    private static func extractLot(from dict: [String: Any]) -> String? {
        for key in lotKeys {
            if let value = stringValue(dict[key]) {
                return value
            }
        }
        return nil
    }

    private static func extractExpiryRaw(from dict: [String: Any]) -> String? {
        for key in expiryKeys {
            if let value = stringValue(dict[key]) {
                return value
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }
            return trimmed
        }
        if let n = value as? NSNumber {
            return n.stringValue
        }
        return nil
    }

    static func parseExpiryString(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }
        guard !LabelLotSanitizer.looksLikeTimeOnly(trimmed) else { return nil }

        if let stamp = LabelStampLineParser.parseExpiry(from: trimmed) {
            return HACCPDateNormalizer.normalizedExpiry(stamp)
        }

        if let local = HACCPDateNormalizer.dateFromDayString(trimmed) {
            return local
        }

        if let parsed = ExpiryDateParser.parse(from: trimmed) {
            return HACCPDateNormalizer.normalizedExpiry(parsed)
        }
        return nil
    }

    private static func extractLotRegex(from payload: String) -> String? {
        let patterns = [
            #""lotto"\s*:\s*"([^"]+)""#,
            #""l"\s*:\s*"([^"]+)""#,
            #""lot(?:to|Code)?"\s*:\s*"([^"]+)""#,
            #""batch"\s*:\s*"([^"]+)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: payload, range: NSRange(payload.startIndex..., in: payload)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: payload) else { continue }
            let candidate = String(payload[range])
            if LabelLotSanitizer.validateLot(candidate) != nil { return candidate }
        }
        return nil
    }

    private static func formatItalian(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        df.locale = Locale(identifier: "it_IT")
        return df.string(from: date)
    }
}
