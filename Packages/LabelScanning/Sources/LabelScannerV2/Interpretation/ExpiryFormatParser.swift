import Foundation

/// Parser date di scadenza V2: numerici, TMC mese/anno, testuali IT/EN/FR/DE, US vs EU.
enum ExpiryFormatParser {
    static func parse(from text: String) -> (date: Date?, raw: String?) {
        let normalized = text
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return (nil, nil) }

        let attempts: [() -> (Date, String)?] = [
            { parseUnambiguousMonthYear(normalized) },
            { parseSeparatedDayMonthYear(normalized) },
            { parseMonthYearSeparated(normalized) },
            { parseTextualMonth(normalized) },
            { parseCompactDigits(normalized) },
            { parseSpaceSeparatedDayMonthYear(normalized) }
        ]
        for attempt in attempts {
            if let result = attempt() { return (result.0, result.1) }
        }
        return (nil, nil)
    }

    /// `12/2028` con anno a 4 cifre — non confondibile con GG/MM/AA.
    private static func parseUnambiguousMonthYear(_ text: String) -> (Date, String)? {
        let pattern = #"\b(0?[1-9]|1[0-2])[\/\-\.](\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            // Evita di leggere "07.2026" dentro "26.07.2026"
            if isPartOfFullDate(match: match, in: text) { continue }
            guard let m = intGroup(match, 1, in: text),
                  let y = intGroup(match, 2, in: text),
                  (2000...2045).contains(y),
                  let date = endOfMonth(month: m, year: y) else { continue }
            return (date, "\(m)/\(y)")
        }
        return nil
    }

    // MARK: - GG/MM/AA · MM/GG/AA · separatori / . -

    private static func parseSeparatedDayMonthYear(_ text: String) -> (Date, String)? {
        let pattern =
            #"(?i)(?:best\s*before(?:\s*end)?|bbe|use\s*by|sell\s*by|scad(?:e|enza)?|exp(?:iry|iration)?|da\s+consumar\w*|entro\s+il|fino\s+al|tmc|preferibilmente)?\s*[:.\-]?\s*(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let a = intGroup(match, 1, in: text),
              let b = intGroup(match, 2, in: text),
              let yRaw = intGroup(match, 3, in: text),
              let (day, month) = resolveDayMonth(first: a, second: b),
              let date = makeDate(day: day, month: month, year: expandYear(yRaw)) else {
            return nil
        }
        return (date, "\(day)/\(month)/\(yRaw)")
    }

    /// EU vs US: se primo > 12 → GG/MM; se secondo > 12 e primo ≤ 12 → MM/GG; altrimenti preferisci EU.
    static func resolveDayMonth(first a: Int, second b: Int) -> (day: Int, month: Int)? {
        if a > 12, (1...12).contains(b), (1...31).contains(a) {
            return (a, b)
        }
        if b > 12, (1...12).contains(a), (1...31).contains(b) {
            return (b, a) // americano MM/GG
        }
        if (1...31).contains(a), (1...12).contains(b) {
            return (a, b) // default europeo
        }
        if (1...12).contains(a), (1...31).contains(b) {
            return (b, a)
        }
        return nil
    }

    // MARK: - MM/AA · MM/AAAA → fine mese

    private static func parseMonthYearSeparated(_ text: String) -> (Date, String)? {
        let pattern =
            #"(?i)(?:best\s*before(?:\s*end)?|bbe|scad(?:e|enza)?|exp(?:iry)?|tmc|use\s*by|sell\s*by)?\s*[:.\-]?\s*\b(\d{1,2})[\/\-\.](\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            // Evita di mangiare GG/MM/AA già parsati: se c'è un terzo gruppo numerico dopo, skip
            guard let m = intGroup(match, 1, in: text),
                  let y = intGroup(match, 2, in: text),
                  (1...12).contains(m) else { continue }
            // Se il match è parte di DD/MM/YYYY (giorno prima del mese), scarta
            if isPartOfFullDate(match: match, in: text) { continue }
            guard let date = endOfMonth(month: m, year: expandYear(y)) else { continue }
            return (date, "\(m)/\(y)")
        }
        return nil
    }

    private static func isPartOfFullDate(match: NSTextCheckingResult, in text: String) -> Bool {
        guard let range = Range(match.range, in: text) else { return false }
        let start = range.lowerBound
        if start > text.startIndex {
            let before = text[text.index(before: start)]
            if before.isNumber || before == "/" || before == "-" || before == "." { return true }
        }
        let after = range.upperBound
        if after < text.endIndex {
            let next = text[after]
            if next == "/" || next == "-" || next == "." {
                let rest = text[after...]
                if rest.range(of: #"^[\/\-\.]\d{2,4}\b"#, options: .regularExpression) != nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Mesi testuali IT/EN/FR/DE

    private static func parseTextualMonth(_ text: String) -> (Date, String)? {
        let months = monthAlternation
        let pattern =
            #"(?i)\b(?:best\s*before(?:\s*end)?|bbe|scad|exp|use\s*by|sell\s*by|tmc)?\s*[:.\-]?\s*(\d{1,2})?\s*("#
            + months
            + #")\.?\s+(\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let monthRange = Range(match.range(at: 2), in: text),
              let year = intGroup(match, 3, in: text),
              let month = monthNumber(String(text[monthRange])) else {
            return nil
        }
        let y = expandYear(year)
        if let day = intGroup(match, 1, in: text) {
            guard let date = makeDate(day: day, month: month, year: y) else { return nil }
            return (date, "\(day) \(String(text[monthRange])) \(year)")
        }
        guard let date = endOfMonth(month: month, year: y) else { return nil }
        return (date, "\(month)/\(year)")
    }

    private static let monthAlternation =
        "jan(?:uary)?|feb(?:ruary|braio)?|mar(?:ch|zo)?|apr(?:il(?:e)?)?|"
        + "may|mai|mag(?:gio)?|jun(?:e)?|giu(?:gno)?|jul(?:y)?|lug(?:lio)?|"
        + "aug(?:ust)?|ago(?:sto)?|sep(?:t(?:ember)?)?|set(?:tembre)?|"
        + "oct(?:ober)?|okt|ott(?:obre)?|nov(?:ember|embre)?|"
        + "dec(?:ember)?|dic(?:embre)?|gen(?:naio)?"

    // MARK: - Compatti GGMMAA · GGMMAAAA · AAMMDD · MMAA

    private static func parseCompactDigits(_ text: String) -> (Date, String)? {
        // 8 cifre: DDMMYYYY o YYYYMMDD
        if let regex = try? NSRegularExpression(pattern: #"\b(\d{8})\b"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let digits = stringGroup(match, 1, in: text),
           let date = parseCompact8(digits) {
            return (date, digits)
        }

        // 6 cifre vicino a keyword / stamp industriale
        let sixPatterns = [
            #"(?i)(?:best\s*before|scad|exp|use\s*by|sell\s*by|tmc).{0,16}?(\d{6})\b"#,
            #"\b(\d{6})\s+\d{1,2}:\d{2}"#,
            #"\b(\d{6})\b"#
        ]
        for pattern in sixPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard let digits = stringGroup(match, 1, in: text),
                      let date = parseCompact6(digits) else { continue }
                return (date, digits)
            }
        }

        // MMAA (4 cifre) solo con contesto TMC/scadenza
        let fourPattern =
            #"(?i)(?:best\s*before(?:\s*end)?|bbe|scad(?:e|enza)?|exp(?:iry)?|tmc)\s*[:.\-]?\s*(\d{4})\b"#
        if let regex = try? NSRegularExpression(pattern: fourPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let digits = stringGroup(match, 1, in: text),
           let date = parseCompactMonthYear(digits) {
            return (date, digits)
        }

        return nil
    }

    private static func parseSpaceSeparatedDayMonthYear(_ text: String) -> (Date, String)? {
        let pattern =
            #"(?i)(?:da\s+consumar\w*|entro|scad|exp|sell\s*by|use\s*by|best\s*before)?\s*[:.\-]?\s*(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let a = intGroup(match, 1, in: text),
              let b = intGroup(match, 2, in: text),
              let y = intGroup(match, 3, in: text),
              let (day, month) = resolveDayMonth(first: a, second: b),
              let date = makeDate(day: day, month: month, year: expandYear(y)) else {
            return nil
        }
        return (date, "\(day) \(month) \(y)")
    }

    // MARK: - Compact helpers

    static func parseCompact6(_ digits: String) -> Date? {
        guard digits.count == 6,
              let a = Int(digits.prefix(2)),
              let b = Int(digits.dropFirst(2).prefix(2)),
              let c = Int(digits.suffix(2)) else { return nil }

        let candidates: [Date?] = [
            makeDate(day: a, month: b, year: expandYear(c)), // DDMMYY EU
            makeDate(day: c, month: b, year: expandYear(a)), // YYMMDD import
            makeDate(day: b, month: a, year: expandYear(c))  // MMDDYY US
        ]
        return preferredNearTermDate(candidates.compactMap { $0 })
    }

    /// Tra interpretazioni compatte valide, scegli l'anno più vicino a oggi (evita 260831 → 2031).
    private static func preferredNearTermDate(_ dates: [Date], reference: Date = Date()) -> Date? {
        guard !dates.isEmpty else { return nil }
        let refYear = Calendar.current.component(.year, from: reference)
        return dates
            .map { date -> (Date, Int) in
                let year = Calendar.current.component(.year, from: date)
                return (date, abs(year - refYear))
            }
            .filter { $0.1 <= 10 }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    static func parseCompact8(_ digits: String) -> Date? {
        guard digits.count == 8,
              let p4 = Int(digits.prefix(4)),
              let mid = Int(digits.dropFirst(4).prefix(2)),
              let suf = Int(digits.suffix(2)) else { return nil }

        // YYYYMMDD
        if (2000...2045).contains(p4), let date = makeDate(day: suf, month: mid, year: p4) {
            return date
        }
        // DDMMYYYY
        let day = Int(digits.prefix(2))!
        let month = Int(digits.dropFirst(2).prefix(2))!
        let year = Int(digits.suffix(4))!
        return makeDate(day: day, month: month, year: year)
    }

    static func parseCompactMonthYear(_ digits: String) -> Date? {
        guard digits.count == 4,
              let month = Int(digits.prefix(2)),
              let yy = Int(digits.suffix(2)),
              (1...12).contains(month) else { return nil }
        return endOfMonth(month: month, year: expandYear(yy))
    }

    // MARK: - Shared

    static func expandYear(_ raw: Int) -> Int {
        if raw >= 100 { return raw }
        let current = Calendar.current.component(.year, from: Date())
        let century = (current / 100) * 100
        var year = century + raw
        if year < current - 2 { year += 100 }
        if year > current + 10 { year -= 100 }
        return year
    }

    static func makeDate(day: Int, month: Int, year: Int) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month), year >= 2000 else { return nil }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        guard let date = Calendar.current.date(from: components) else { return nil }
        // Verifica no overflow (31/02 → nil via calendar mismatch)
        let check = Calendar.current.dateComponents([.day, .month, .year], from: date)
        guard check.day == day, check.month == month, check.year == year else { return nil }
        return date
    }

    static func endOfMonth(month: Int, year: Int) -> Date? {
        guard (1...12).contains(month) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        return Calendar.current.date(from: components)
    }

    static func monthNumber(_ raw: String) -> Int? {
        let key = String(raw.lowercased().prefix(3))
        let map: [String: Int] = [
            "jan": 1, "gen": 1,
            "feb": 2,
            "mar": 3,
            "apr": 4,
            "may": 5, "mai": 5, "mag": 5,
            "jun": 6, "giu": 6,
            "jul": 7, "lug": 7,
            "aug": 8, "ago": 8,
            "sep": 9, "set": 9,
            "oct": 10, "okt": 10, "ott": 10,
            "nov": 11,
            "dec": 12, "dic": 12
        ]
        return map[key]
    }

    private static func intGroup(_ match: NSTextCheckingResult, _ index: Int, in string: String) -> Int? {
        guard let s = stringGroup(match, index, in: string) else { return nil }
        return Int(s)
    }

    private static func stringGroup(_ match: NSTextCheckingResult, _ index: Int, in string: String) -> String? {
        guard match.numberOfRanges > index,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: string) else { return nil }
        return String(string[range])
    }
}
