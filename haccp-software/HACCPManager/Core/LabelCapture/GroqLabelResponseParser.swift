import Foundation

/// Parsing e validazione locale della risposta Groq (zero token extra).
enum GroqLabelResponseParser {
    struct Parsed: Sendable {
        var lot: String?
        var expiry: Date?
        var expiryKind: String?
        var modelConfidence: String?
        var rawPayload: String
        var audit: [String]

        var isComplete: Bool { lot != nil && expiry != nil }

        func merging(_ other: Parsed) -> Parsed {
            Parsed(
                lot: preferredLot(lot, other.lot),
                expiry: preferredExpiry(expiry, other.expiry),
                expiryKind: expiryKind ?? other.expiryKind,
                modelConfidence: preferredModelConfidence(modelConfidence, other.modelConfidence),
                rawPayload: mergedPayload(rawPayload, other.rawPayload),
                audit: audit + other.audit
            )
        }

        private func preferredModelConfidence(_ a: String?, _ b: String?) -> String? {
            rank(a) >= rank(b) ? (a ?? b) : (b ?? a)
        }

        private func rank(_ value: String?) -> Int {
            switch value?.lowercased() {
            case "high", "alta": return 3
            case "medium", "media": return 2
            case "low", "bassa": return 1
            default: return 0
            }
        }

        private func preferredLot(_ a: String?, _ b: String?) -> String? {
            guard let a else { return b }
            guard let b else { return a }
            let issuesA = GroqLabelValidator.issues(lot: a, expiry: expiry, rawContext: rawPayload)
            let issuesB = GroqLabelValidator.issues(lot: b, expiry: expiry, rawContext: rawPayload)
            if issuesA.contains(.lotLooksLikeDate) && !issuesB.contains(.lotLooksLikeDate) { return b }
            if issuesB.contains(.lotLooksLikeDate) && !issuesA.contains(.lotLooksLikeDate) { return a }
            if issuesA.contains(.lotMissingLeadingLetter) && !issuesB.contains(.lotMissingLeadingLetter) { return b }
            if issuesB.contains(.lotMissingLeadingLetter) && !issuesA.contains(.lotMissingLeadingLetter) { return a }
            if a.hasPrefix("L"), !b.hasPrefix("L"), b.caseInsensitiveCompare(String(a.dropFirst())) == .orderedSame { return a }
            if b.hasPrefix("L"), !a.hasPrefix("L"), a.caseInsensitiveCompare(String(b.dropFirst())) == .orderedSame { return b }
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
        var expiryKind: String?
        var modelConfidence: String?
        var rawStampLine: String?

        if let dict = jsonDictionary(from: payload) {
            let lotFound = boolValue(dict["lotto_found"])
                ?? boolValue(dict["lotto_trovato"])
            let expiryFound = boolValue(dict["expiration_found"])
                ?? boolValue(dict["scadenza_trovata"])

            rawStampLine = stringValue(dict["raw_stamp_line"])
                ?? stringValue(dict["riga_stampa"])

            if lotFound != false {
                lot = extractLot(from: dict)
            } else {
                audit.append("Model: lotto_found=false")
            }

            if expiryFound != false {
                expiryRaw = extractExpiryRaw(from: dict)
            } else {
                audit.append("Model: expiration_found=false")
            }

            expiryKind = stringValue(dict["expiration_type"])
                ?? stringValue(dict["tipo_scadenza"])
            modelConfidence = stringValue(dict["confidence_score"])
                ?? stringValue(dict["confidenza_estrazione"])
        }

        if lot == nil {
            lot = extractLotRegex(from: payload)
            if lot != nil { audit.append("Lotto da estrazione JSON parziale") }
        }

        let sanitizerContext = [payload, rawStampLine ?? ""].filter { !$0.isEmpty }.joined(separator: "\n")
        if let rawStampLine, let stampLot = LabelStampLineParser.extractLot(from: rawStampLine) {
            lot = lot.map { preferredStandaloneLot($0, stampLot) } ?? stampLot
            audit.append("Lotto da riga stampa verbatim")
        } else if let stampLot = LabelStampLineParser.extractLot(from: sanitizerContext) {
            lot = lot.map { preferredStandaloneLot($0, stampLot) } ?? stampLot
            audit.append("Lotto da pattern riga stampa")
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

        lot = lot.flatMap { LabelLotSanitizer.validateLot($0, rawContext: sanitizerContext) }

        var validatedExpiry: Date? = expiry
        if let candidate = validatedExpiry {
            if GroqLabelValidator.issues(lot: lot, expiry: candidate, rawContext: sanitizerContext)
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
        if let expiryKind, !expiryKind.isEmpty {
            audit.append("Tipo scadenza: \(expiryKind)")
        }
        if let modelConfidence, !modelConfidence.isEmpty {
            audit.append("Confidenza modello: \(modelConfidence)")
        }

        return Parsed(
            lot: lot,
            expiry: expiry,
            expiryKind: expiryKind,
            modelConfidence: modelConfidence,
            rawPayload: payload,
            audit: audit
        )
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
        switch parsed.modelConfidence?.lowercased() {
        case "high", "alta":
            score = max(score, 0.90)
        case "medium", "media":
            score = min(score, 0.82)
        case "low", "bassa":
            score = min(score, 0.65)
        default:
            break
        }
        if issues.contains(.lotLooksLikeDate) { score -= 0.35 }
        if issues.contains(.lotLooksLikeBarcode) { score -= 0.30 }
        if issues.contains(.expiryUnreasonable) { score -= 0.25 }
        if issues.contains(.expiryLooksLikeProductionTime) { score -= 0.40 }
        if issues.contains(.lotMissingLeadingLetter) { score -= 0.30 }
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
        "expiration_date", "scadenza", "e", "exp", "expiry", "expirydate", "expiry_date",
        "tmc", "data", "data_scadenza"
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

    private static func boolValue(_ value: Any?) -> Bool? {
        guard let value else { return nil }
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String {
            switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "si", "sì": return true
            case "false", "0", "no": return false
            default: return nil
            }
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

    private static func preferredStandaloneLot(_ a: String, _ b: String) -> String {
        if LabelLotSanitizer.validateLot(a) == nil { return b }
        if LabelLotSanitizer.validateLot(b) == nil { return a }
        if a.hasPrefix("L"), !b.hasPrefix("L"), b.caseInsensitiveCompare(String(a.dropFirst())) == .orderedSame { return a }
        if b.hasPrefix("L"), !a.hasPrefix("L"), a.caseInsensitiveCompare(String(b.dropFirst())) == .orderedSame { return b }
        return a.count >= b.count ? a : b
    }

    private static func formatItalian(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        df.locale = Locale(identifier: "it_IT")
        return df.string(from: date)
    }
}
