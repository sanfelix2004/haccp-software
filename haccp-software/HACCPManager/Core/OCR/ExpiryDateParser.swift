import Foundation

/// Estrae date di scadenza da testo etichetta (TMC, SCAD, SCADE, GS1 17, MM/YYYY, ecc.).
enum ExpiryDateParser {

    static func parse(from rawText: String) -> Date? {
        let lines = rawText
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parse(fromLines: lines.isEmpty ? [rawText] : lines)
    }

    static func parse(fromLines lines: [String]) -> Date? {
        let normalizedLines = lines
            .map { normalizeExpiryLine($0) }
            .filter { !$0.isEmpty }
        let flat = normalizedLines.joined(separator: " ")
        if let gs1 = parseGS1Expiry(in: flat) { return gs1 }

        var best: (date: Date, score: Double)?
        for line in normalizedLines {
            let expiryLine = isExpiryContextLine(line)
            for match in dateMatches(in: line) {
                guard let date = makeDate(from: match) else { continue }
                var score = match.score
                if expiryLine { score += 0.35 }
                if best.map({ score > $0.score }) ?? true {
                    best = (date, score)
                }
            }
        }
        return best?.date
    }

    static func parseISO(_ value: String?, referenceDate: Date = Date()) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        let normalized = normalizeExpiryLine(value)

        if let slashDate = parseSlashSeparatedISO(normalized, referenceDate: referenceDate) {
            return slashDate
        }

        let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "dd.MM.yyyy", "MM/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = TimeZone.current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) {
                if format == "MM/yyyy" {
                    return endOfMonth(for: date, calendar: Calendar.current)
                }
                return Calendar.current.startOfDay(for: date)
            }
        }
        return parse(from: normalized)
    }

    /// Espande un anno a 2 cifre scegliendo il secolo più plausibile rispetto alla data di riferimento.
    static func expandTwoDigitYear(_ year: Int, referenceDate: Date = Date()) -> Int {
        guard year >= 0, year < 100 else { return year }
        let currentYear = Calendar.current.component(.year, from: referenceDate)
        let candidates = [2000 + year, 1900 + year]
        return candidates.min(by: { abs($0 - currentYear) < abs($1 - currentYear) }) ?? (2000 + year)
    }

    // MARK: - Private

    private enum DateShape {
        case dayMonthYear(day: Int, month: Int, year: Int)
        case monthYear(month: Int, year: Int)
    }

    private struct DateMatch {
        let shape: DateShape
        let score: Double
    }

    private static let gs1ExpiryPattern = #"(?i)\(17\)\s*(\d{6})"#

    private static let fullDatePatterns: [(pattern: String, score: Double)] = [
        (#"(?i)(?:lotto|lot\b|l\.).*?\bscad(?:e|enza)?\s*[:.\-]?\s*(\d{1,2})\s*[\/\-\.]\s*(\d{1,2})\s*[\/\-\.]?\s*(\d{2,4})"#, 0.96),
        (#"(?i)(?:tmc|scad(?:e|enza)?|exp(?:iry)?|use\s*by|best\s*before|da\s+consumar\w*|consumar\w*\s+entro)\s*[:.\-]?\s*(\d{1,2})\s*[\/\-\.]\s*(\d{1,2})\s*[\/\-\.]?\s*(\d{2,4})"#, 0.95),
        (#"(?i)(?:tmc|scad(?:e|enza)?|exp(?:iry)?)\s+(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})"#, 0.90),
        (#"(\d{1,2})\s*[\/\-\.]\s*(\d{1,2})\s*[\/\-\.]+\s*(\d{2,4})(?!\d)"#, 0.55),
    ]

    /// Solo mese/anno — tipico «SCADE: 12/2029» su spezie e conserve.
    private static let monthYearPatterns: [(pattern: String, score: Double)] = [
        (#"(?i)(?:tmc|scad(?:e|enza)?|exp(?:iry)?|use\s*by|best\s*before|da\s+consumar\w*)\s*[:.\-]?\s*(\d{1,2})\s*[\/\-\.]\s*(\d{2,4})"#, 0.93),
        (#"(?i)\bscad(?:e|enza)?\s*[:.\-]?\s*(\d{1,2})\s*[\/\-\.]\s*(\d{2,4})"#, 0.94),
        (#"\b(\d{1,2})\s*[\/\-\.]\s*(\d{4})\b"#, 0.48),
        (#"\b(\d{1,2})\s*[\/\-\.]\s*(\d{2})\b"#, 0.46),
    ]

    private static let expiryLinePatterns: [String] = [
        #"(?i)da\s+consum"#, #"(?i)consumar"#, #"(?i)preferibilmente"#,
        #"(?i)entro\s+il"#, #"(?i)scad(?:e|enza)?"#, #"(?i)best\s+before"#,
        #"(?i)use\s+by"#, #"(?i)exp(?:iry)?"#, #"(?i)\btmc\b"#
    ]

    private static func parseGS1Expiry(in text: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: gs1ExpiryPattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let digits = String(text[range])
        guard digits.count == 6,
              let year = Int(digits.prefix(2)),
              let month = Int(digits.dropFirst(2).prefix(2)),
              let day = Int(digits.suffix(2)) else { return nil }
        return makeDate(day: day, month: month, year: expandTwoDigitYear(year))
    }

    /// Normalizza righe OCR sporche prima del parsing (spazi, separatori, «Scad» abbreviato).
    private static func normalizeExpiryLine(_ line: String) -> String {
        var value = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        value = value.replacingOccurrences(
            of: #"(?i)\bscad(?:e|enza)?\b"#,
            with: "SCAD",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?i)\btmc\b"#,
            with: "TMC",
            options: .regularExpression
        )

        // Solo date tripartite dd/mm/yy — non toccare MM/YYYY (es. 12/2029).
        value = value.replacingOccurrences(
            of: #"(\d{1,2})\s*[\/\-\.]\s*(\d{1,2})\s*[\/\-\.]+\s*(\d{2,4})(?!\d)"#,
            with: "$1/$2/$3",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseSlashSeparatedISO(_ value: String, referenceDate: Date) -> Date? {
        let pattern = #"^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.numberOfRanges >= 4,
              let dRange = Range(match.range(at: 1), in: value),
              let mRange = Range(match.range(at: 2), in: value),
              let yRange = Range(match.range(at: 3), in: value),
              let day = Int(value[dRange]),
              let month = Int(value[mRange]),
              let rawYear = Int(value[yRange]) else { return nil }

        let year = rawYear < 100 ? expandTwoDigitYear(rawYear, referenceDate: referenceDate) : rawYear
        return makeDate(day: day, month: month, year: year, referenceDate: referenceDate)
    }

    private static func dateMatches(in line: String) -> [DateMatch] {
        var results: [DateMatch] = []

        for (pattern, score) in fullDatePatterns {
            collectMatches(pattern: pattern, in: line, score: score, groups: 3, into: &results)
        }
        for (pattern, score) in monthYearPatterns {
            collectMatches(pattern: pattern, in: line, score: score, groups: 2, into: &results)
        }
        return results
    }

    private static func collectMatches(
        pattern: String,
        in line: String,
        score: Double,
        groups: Int,
        into results: inout [DateMatch]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsRange = NSRange(line.startIndex..., in: line)
        regex.enumerateMatches(in: line, range: nsRange) { match, _, _ in
            guard let match else { return }
            if groups == 3,
               match.numberOfRanges >= 4,
               let dRange = Range(match.range(at: 1), in: line),
               let mRange = Range(match.range(at: 2), in: line),
               let yRange = Range(match.range(at: 3), in: line),
               let day = Int(line[dRange]),
               let month = Int(line[mRange]),
               let year = Int(line[yRange]) {
                results.append(DateMatch(shape: .dayMonthYear(day: day, month: month, year: year), score: score))
            } else if groups == 2,
                      match.numberOfRanges >= 3,
                      let mRange = Range(match.range(at: 1), in: line),
                      let yRange = Range(match.range(at: 2), in: line),
                      let month = Int(line[mRange]),
                      let year = Int(line[yRange]) {
                results.append(DateMatch(shape: .monthYear(month: month, year: year), score: score))
            }
        }
    }

    private static func makeDate(from match: DateMatch, referenceDate: Date = Date()) -> Date? {
        switch match.shape {
        case let .dayMonthYear(day, month, year):
            return makeDate(day: day, month: month, year: year, referenceDate: referenceDate)
        case let .monthYear(month, year):
            return endOfMonth(month: month, year: year, referenceDate: referenceDate)
        }
    }

    private static func isExpiryContextLine(_ line: String) -> Bool {
        expiryLinePatterns.contains { pattern in
            (try? NSRegularExpression(pattern: pattern))?.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
            ) != nil
        }
    }

    private static func makeDate(
        day: Int,
        month: Int,
        year: Int,
        referenceDate: Date = Date()
    ) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
        let y = year < 100 ? expandTwoDigitYear(year, referenceDate: referenceDate) : year
        guard y >= 1990, y <= 2100 else { return nil }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = y
        guard let date = Calendar.current.date(from: components) else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

    /// Fine mese per etichette «SCADE: MM/YYYY» (norma prassi alimentare UE).
    private static func endOfMonth(
        month: Int,
        year: Int,
        referenceDate: Date = Date()
    ) -> Date? {
        guard (1...12).contains(month) else { return nil }
        let y = year < 100 ? expandTwoDigitYear(year, referenceDate: referenceDate) : year
        guard y >= 1990, y <= 2100 else { return nil }
        let calendar = Calendar.current
        var components = DateComponents(year: y, month: month, day: 1)
        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else { return nil }
        components.day = dayRange.count
        guard let date = calendar.date(from: components) else { return nil }
        return calendar.startOfDay(for: date)
    }

    private static func endOfMonth(for date: Date, calendar: Calendar) -> Date? {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let month = parts.month, let year = parts.year else { return nil }
        return endOfMonth(month: month, year: year)
    }
}

#if DEBUG
enum ExpiryDateParserSelfCheck {
    static func run() -> [String] {
        var failures: [String] = []
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 22)) ?? Date()
        let cases: [(input: String, expectedDay: Int, expectedMonth: Int, expectedYear: Int)] = [
            ("L.: 0526 SCADE: 12/2029", 31, 12, 2029),
            ("TMC 12/11/2026", 12, 11, 2026),
            ("Scad. 05/07/26", 5, 7, 2026),
            ("Da consumarsi pref. entro il: 15/06/2027", 15, 6, 2027),
            ("Scad 12-10- 26", 12, 10, 2026),
            ("TMC: 12/2026", 31, 12, 2026),
            ("Lotto e Scad: 12.10.26", 12, 10, 2026),
        ]
        let calendar = Calendar.current
        for item in cases {
            guard let date = ExpiryDateParser.parse(from: item.input) else {
                failures.append("Nessuna scadenza da «\(item.input)»")
                continue
            }
            let c = calendar.dateComponents([.day, .month, .year], from: date)
            if c.day != item.expectedDay || c.month != item.expectedMonth || c.year != item.expectedYear {
                failures.append(
                    "«\(item.input)» atteso \(item.expectedDay)/\(item.expectedMonth)/\(item.expectedYear), " +
                    "trovato \(c.day ?? -1)/\(c.month ?? -1)/\(c.year ?? -1)"
                )
            }
        }

        if ExpiryDateParser.expandTwoDigitYear(26, referenceDate: reference) != 2026 {
            failures.append("expandTwoDigitYear(26) atteso 2026")
        }
        if ExpiryDateParser.expandTwoDigitYear(99, referenceDate: reference) != 1999 {
            failures.append("expandTwoDigitYear(99) atteso 1999 (più vicino al 2026)")
        }

        return failures
    }
}
#endif
