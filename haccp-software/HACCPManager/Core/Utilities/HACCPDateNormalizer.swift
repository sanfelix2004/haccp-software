import Foundation

/// Normalizzazione date HACCP — sempre mezzanotte nel fuso locale (no drift UTC).
enum HACCPDateNormalizer {

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    static func startOfLocalDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Normalizza una scadenza per persistenza (Tracciabilità, LottoFoto, Etichette).
    static func normalizedExpiry(_ date: Date) -> Date {
        startOfLocalDay(date)
    }

    /// Interpreta stringhe «solo data» nel calendario locale (yyyy-MM-dd, dd/MM/yyyy, …).
    static func dateFromDayString(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let patterns: [(String, (Int, Int, Int) -> DateComponents?)] = [
            (#"^(\d{4})-(\d{2})-(\d{2})$"#, { y, m, d in dayComponents(year: y, month: m, day: d) }),
            (#"^(\d{4})/(\d{2})/(\d{2})$"#, { y, m, d in dayComponents(year: y, month: m, day: d) }),
            (#"^(\d{1,2})/(\d{1,2})/(\d{4})$"#, { d, m, y in dayComponents(year: y, month: m, day: d) }),
            (#"^(\d{1,2})-(\d{1,2})-(\d{4})$"#, { d, m, y in dayComponents(year: y, month: m, day: d) }),
            (#"^(\d{1,2})\.(\d{1,2})\.(\d{4})$"#, { d, m, y in dayComponents(year: y, month: m, day: d) }),
            (#"^(\d{1,2})/(\d{1,2})/(\d{2})$"#, { d, m, yy in
                dayComponents(year: ExpiryDateParser.expandTwoDigitYear(yy), month: m, day: d)
            }),
            (#"^(\d{1,2})-(\d{1,2})-(\d{2})$"#, { d, m, yy in
                dayComponents(year: ExpiryDateParser.expandTwoDigitYear(yy), month: m, day: d)
            }),
            (#"^(\d{1,2})\.(\d{1,2})\.(\d{2})$"#, { d, m, yy in
                dayComponents(year: ExpiryDateParser.expandTwoDigitYear(yy), month: m, day: d)
            })
        ]

        for (pattern, builder) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  match.numberOfRanges >= 4,
                  let r1 = Range(match.range(at: 1), in: trimmed),
                  let r2 = Range(match.range(at: 2), in: trimmed),
                  let r3 = Range(match.range(at: 3), in: trimmed),
                  let a = Int(trimmed[r1]),
                  let b = Int(trimmed[r2]),
                  let c = Int(trimmed[r3]),
                  let components = builder(a, b, c),
                  let date = calendar.date(from: components) else { continue }
            return startOfLocalDay(date)
        }
        return nil
    }

    private static func dayComponents(year: Int, month: Int, day: Int) -> DateComponents? {
        guard (1...31).contains(day), (1...12).contains(month), year >= 1990, year <= 2100 else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return components
    }
}

#if DEBUG
enum HACCPDateNormalizerSelfCheck {
    static func run() -> [String] {
        var failures: [String] = []
        let cal = HACCPDateNormalizer.calendar

        let cases = [
            ("2026-08-23", 23, 8, 2026),
            ("23/08/2026", 23, 8, 2026),
            ("23-08-26", 23, 8, 2026)
        ]
        for (input, expDay, expMonth, expYear) in cases {
            guard let date = HACCPDateNormalizer.dateFromDayString(input) else {
                failures.append("Nessuna data da «\(input)»")
                continue
            }
            let parts = cal.dateComponents([.day, .month, .year], from: date)
            if parts.day != expDay || parts.month != expMonth || parts.year != expYear {
                failures.append("«\(input)» atteso \(expDay)/\(expMonth)/\(expYear), trovato \(parts.day ?? -1)/\(parts.month ?? -1)/\(parts.year ?? -1)")
            }
        }

        if HACCPDateNormalizer.dateFromDayString("2026-08-23") != HACCPDateNormalizer.startOfLocalDay(
            HACCPDateNormalizer.dateFromDayString("2026-08-23") ?? Date()
        ) {
            failures.append("startOfLocalDay non idempotente")
        }

        return failures
    }
}
#endif
