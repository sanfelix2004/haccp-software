import Foundation

/// Fallback deterministico lotto/scadenza — copre i formati HACCP documentati per V2.
public struct RegexFallbackInterpreter: Sendable {
    public init() {}

    public func interpret(lines: [String]) -> InterpretedLabelFields {
        let joined = lines.joined(separator: "\n")
        let lot = extractLot(from: joined, lines: lines)
        let expiry = extractExpiry(from: joined, lines: lines)
        var confidence = 0.35
        if lot != nil { confidence += 0.2 }
        if expiry.date != nil { confidence += 0.2 }
        if lot != nil, expiry.date != nil { confidence += 0.1 }
        return InterpretedLabelFields(
            lotto: lot,
            scadenza: expiry.date,
            scadenzaRawText: expiry.raw,
            confidence: min(confidence, 0.85)
        )
    }

    // MARK: - Lot

    public func extractLot(from text: String, lines: [String]? = nil) -> String? {
        // Stampigliatura coperchio: "J11LR233 12/2028 L1" → J11LR233 (non L1)
        if let stamped = extractLotFromIndustrialStampLine(text) {
            return stamped
        }
        // Uova / centro imballaggio: "(Z) Z63648"
        if let parenthetical = extractParentheticalPlantLot(text) {
            return parenthetical
        }
        // Orario attaccato al lotto: "08:14F0602 67661"
        if let timed = extractTimeGluedLot(text) {
            return timed
        }

        typealias Candidate = (pattern: String, group: Int, transform: (String) -> String, minLen: Int, priority: Int)

        let candidates: [Candidate] = [
            (#"(?i)\b(\d{1,2}:\d{2}H-[A-Z0-9]{2,12})\b"#, 1, { $0 }, 5, 100),
            (#"(?i)\b(\d{1,2}:\d{2}[A-Z][A-Z0-9]*-[A-Z0-9]{1,12})\b"#, 1, { $0 }, 5, 100),
            // Orario + codice senza spazio: 08:14F0602
            (#"(?i)\b\d{1,2}:\d{2}([A-Z][A-Z0-9]{2,16})\b"#, 1, { $0 }, 4, 95),
            (#"(?i)\b\d{1,2}:\d{2}\s+([A-Z0-9][A-Z0-9./_#:-]{1,16})\b"#, 1, { $0 }, 2, 80),
            (#"(?i)\b([A-Z0-9][A-Z0-9./_#:-]{1,16})\s+\d{1,2}:\d{2}\b"#, 1, { $0 }, 2, 80),

            (#"(?i)\bL\.\s*([0-9A-Z][0-9A-Z./_#:-]{0,22})\b"#, 1, { "L." + $0 }, 2, 90),
            (#"(?i)\bL[:.]\s*([0-9A-Z][0-9A-Z./_#:-]{0,22})\b"#, 1, { "L." + $0 }, 2, 90),
            (#"(?i)\b(?:batch|lot(?:to)?)\s*(?:number|no\.?|nr\.?|#)\s*[:.=]?\s*([0-9A-Z][0-9A-Z./_#:-]{0,22})\b"#, 1, { $0 }, 2, 90),
            (#"(?i)\bB\.?\s*N\.?\s*[:.=]?\s*([0-9A-Z][0-9A-Z./_#:-]{1,22})\b"#, 1, { $0 }, 2, 90),
            (#"(?i)\b(?:lot(?:to)?|batch|partita)\s*[:#.=]\s*((?:#)?[0-9A-Z][0-9A-Z./_#:-]{1,22})\b"#, 1, { $0 }, 2, 90),
            (#"(?i)\bLOT\s+([0-9A-Z][0-9A-Z./_#:-]{1,22})\b"#, 1, { $0 }, 2, 90),

            // Alfanumerico lungo (J11LR233) e lettera+cifre (Z63648)
            (#"(?i)\b([A-Z]\d{2,10}[A-Z0-9]{2,10})\b"#, 1, { $0 }, 5, 85),
            (#"(?i)\b([A-Z]\d{4,12})\b"#, 1, { $0 }, 5, 82),
            (#"(?i)\b(\d{3,8}[A-Z]{1,4}\d{0,6})\b"#, 1, { $0 }, 4, 70),

            (#"(?i)(?<![A-Z])L([A-Z0-9]*\d[A-Z0-9]{1,16})\b"#, 1, { "L" + $0 }, 3, 75),
            (#"(?i)\b([A-Z0-9]{1,8}[-_/][A-Z0-9]{1,12})\b"#, 1, { $0 }, 3, 70),

            (#"(?i)\b\d{6}\s+\d{1,2}:\d{2}(?::\d{2})?\s+([A-Z0-9]{2,12})\b"#, 1, { $0 }, 2, 80),
            (#"(?i)\b(\d{4,8})\s+\d{1,2}:\d{2}\b"#, 1, { $0 }, 4, 60),
            (#"(?i)\b(\d{6,12}[A-Z0-9]{1,4}-\d{2})\b"#, 1, { $0 }, 5, 70),

            // L1 / L2 — priorità bassa
            (#"(?i)\bL(?![A-Z]{3,})([0-9A-Z][0-9A-Z./_#:-]{0,20})\b"#, 1, { "L" + $0 }, 2, 20),
        ]

        var best: (value: String, score: Int)?
        for candidate in candidates {
            guard let regex = try? NSRegularExpression(pattern: candidate.pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard match.numberOfRanges > candidate.group,
                      let gRange = Range(match.range(at: candidate.group), in: text) else { continue }
                let raw = candidate.transform(String(text[gRange]))
                guard let normalized = LotNormalizer.normalize(raw, minimumLength: candidate.minLen) else { continue }
                // Non premiare stringhe lunghissime (disclaimer OCR attaccati)
                let lengthBonus = min(normalized.count, 14)
                let score = candidate.priority * 10 + lengthBonus
                if best.map({ score > $0.score }) ?? true {
                    best = (normalized, score)
                }
            }
        }
        if let best { return best.value }

        let sourceLines = lines ?? text.components(separatedBy: .newlines)
        for (index, line) in sourceLines.enumerated() {
            guard LabelKeywordDictionary.isLotContext(line) else { continue }
            let same = stripLotPrefix(line)
            if let normalized = LotNormalizer.normalize(same, minimumLength: 2) { return normalized }
            if index + 1 < sourceLines.count,
               let normalized = LotNormalizer.normalize(sourceLines[index + 1], minimumLength: 2) {
                return normalized
            }
        }

        return extractImplicitLotNearDate(lines: sourceLines)
    }

    /// `J11LR233 12/2028 L1`
    private func extractLotFromIndustrialStampLine(_ text: String) -> String? {
        let pattern =
            #"(?i)\b([A-Z][A-Z0-9]{4,16})\s+(\d{1,2})[\/\-\.](\d{2,4})(?:\s+L\d{1,3})?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 4,
              let lotRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let month = Int(text[monthRange]),
              (1...12).contains(month) else {
            return nil
        }
        return LotNormalizer.normalize(String(text[lotRange]), minimumLength: 5)
    }

    /// Uova / centro imballaggio UE: "(Z) Z63648" o "(Z)Z63648"
    private func extractParentheticalPlantLot(_ text: String) -> String? {
        let pattern = #"(?i)\(([A-Z0-9]{1,4})\)\s*([A-Z0-9][A-Z0-9./_#:-]{2,20})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let plantRange = Range(match.range(at: 1), in: text),
              let lotRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        let plant = String(text[plantRange]).uppercased()
        let lot = String(text[lotRange]).uppercased()
        if let full = LotNormalizer.normalize("(\(plant))\(lot)", minimumLength: 5) {
            return full
        }
        return LotNormalizer.normalize(lot, minimumLength: 4)
    }

    /// `08:14F0602 67661` → F060267661 (orario produzione + codice, senza spazio dopo l'orario).
    private func extractTimeGluedLot(_ text: String) -> String? {
        let pattern = #"(?i)\b\d{1,2}:\d{2}([A-Z][A-Z0-9]{2,16})(?:\s+(\d{3,10}))?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let codeRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        var code = String(text[codeRange]).uppercased()
        if match.numberOfRanges >= 3,
           match.range(at: 2).location != NSNotFound,
           let numRange = Range(match.range(at: 2), in: text) {
            code += String(text[numRange])
        }
        return LotNormalizer.normalize(code, minimumLength: 4)
    }

    private func extractImplicitLotNearDate(lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let expiry = ExpiryFormatParser.parse(from: line)
            guard expiry.date != nil else { continue }
            for neighbor in [index - 1, index + 1] where lines.indices.contains(neighbor) {
                let candidate = lines[neighbor].trimmingCharacters(in: .whitespacesAndNewlines)
                if ExpiryFormatParser.parse(from: candidate).date != nil { continue }
                if LabelKeywordDictionary.isExpiryContext(candidate) { continue }
                if let normalized = LotNormalizer.normalize(candidate, minimumLength: 2) {
                    return normalized
                }
            }
        }
        return nil
    }

    private func stripLotPrefix(_ line: String) -> String {
        var value = line
        let patterns = [
            #"(?i)^(?:batch|lot(?:to)?)\s*(?:number|no\.?|nr\.?|#)?\s*[:.=]?\s*"#,
            #"(?i)^B\.?\s*N\.?\s*[:.=]?\s*"#,
            #"(?i)^(?:partita|cod(?:ice)?\s*lotto)\s*[:.=]?\s*"#,
            #"(?i)^L[.:]?\s*"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range, in: value) {
                value = String(value[range.upperBound...])
                break
            }
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Expiry

    public func extractExpiry(from text: String, lines: [String]? = nil) -> (date: Date?, raw: String?) {
        let direct = ExpiryFormatParser.parse(from: text)
        if direct.date != nil { return direct }

        let sourceLines = lines ?? text.components(separatedBy: .newlines)
        for (index, line) in sourceLines.enumerated() {
            guard LabelKeywordDictionary.isExpiryContext(line) else { continue }
            let probe = [line, index + 1 < sourceLines.count ? sourceLines[index + 1] : ""]
                .joined(separator: " ")
            let nested = ExpiryFormatParser.parse(from: probe)
            if nested.date != nil { return nested }
        }
        return (nil, nil)
    }
}
