import Foundation

/// Ripara Codice↔Descrizione scambiati e campi uniti tipici OCR.
enum InvoiceLineNormalizer {
    private static let headerTokens: Set<String> = [
        "CODICE", "LOTTO", "DESCRIZIONE", "U.M.", "UM", "COLLI",
        "QUANTITA", "QUANTITÀ", "PREZZO", "PREZZO UN.", "IVA",
        "IMP. NETTO", "SC.1%", "SC. 1%"
    ]

    static func normalizeAll(_ rows: [InvoiceLineItem]) -> [InvoiceLineItem] {
        var seen = Set<String>()
        var out: [InvoiceLineItem] = []
        for row in rows {
            guard let n = normalize(row) else { continue }
            let key = "\(n.productCode ?? "")|\(n.lotCode ?? "")|\(n.description.uppercased())"
            if seen.insert(key).inserted {
                out.append(n)
            }
        }
        return out
    }

    static func normalize(_ row: InvoiceLineItem) -> InvoiceLineItem? {
        var code = clean(row.productCode)
        var lot = clean(row.lotCode)
        var desc = clean(row.description) ?? ""

        // "FRUTTIDIBOSCO00: 4624847" nel lotto
        if let lotValue = lot, let split = splitMergedCodeAndLot(lotValue) {
            if code == nil || isHeaderToken(code) || looksLikeProductDescription(code ?? "") {
                code = split.code
            }
            lot = split.lot
        }

        // "POMODORI001 36594" nel codice
        if let codeValue = code, let split = splitMergedCodeAndLot(codeValue) {
            code = split.code
            if lot == nil { lot = split.lot }
        }

        // Intestazione finita nel codice
        if isHeaderToken(code) {
            if looksLikeArticleCode(desc) {
                code = desc
                desc = ""
            } else {
                code = nil
            }
        }
        if isHeaderToken(lot) { lot = nil }
        if isHeaderToken(desc) { return nil }

        // Swap classico: codice=descrizione lunga, descrizione=codice corto
        if looksLikeProductDescription(code ?? ""), looksLikeArticleCode(desc) {
            let previousCode = code
            code = desc
            desc = previousCode ?? ""
        }

        // Swap inverso raro: codice=token articolo, descrizione=ancora codice → incompleta
        code = clean(code)
        lot = clean(lot)
        desc = (clean(desc) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !desc.isEmpty else { return nil }
        guard looksLikeArticleCode(code) else { return nil }
        guard looksLikeProductDescription(desc) else { return nil }
        // Descrizione non deve essere un secondo codice
        if looksLikeArticleCode(desc) { return nil }

        return InvoiceLineItem(
            id: row.id,
            productCode: code,
            lotCode: looksLikeLot(lot) ? lot : nil,
            description: desc
        )
    }

    // MARK: - Heuristics

    static func clean(_ value: String?) -> String? {
        guard var t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return nil
        }
        if t == "—" || t == "-" || t.lowercased() == "null" { return nil }
        for prefix in ["Codice:", "Lotto:", "Descrizione:"] {
            if t.lowercased().hasPrefix(prefix.lowercased()) {
                t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return t.isEmpty ? nil : t
    }

    static func isHeaderToken(_ value: String?) -> Bool {
        guard let value else { return false }
        return headerTokens.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    /// Codice articolo: un solo token con lettere (DATTGIALLO, MELANZANE001, TIM).
    static func looksLikeArticleCode(_ value: String?) -> Bool {
        guard let value else { return false }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2, t.count <= 32 else { return false }
        if isHeaderToken(t) { return false }
        if t.contains(" ") || t.contains("@") || t.contains("^") { return false }
        guard t.filter(\.isLetter).count >= 1 else { return false }
        return t.range(of: #"^[A-Za-z][A-Za-z0-9._\-/]*$"#, options: .regularExpression) != nil
    }

    static func looksLikeLot(_ value: String?) -> Bool {
        guard let value else { return false }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 4, t.count <= 12 else { return false }
        return t.allSatisfy(\.isNumber)
    }

    /// Descrizione prodotto: spazi e/o marker tipici (italia, 1^, vaso…).
    static func looksLikeProductDescription(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 3 else { return false }
        if isHeaderToken(t) { return false }
        if looksLikeArticleCode(t) { return false }
        let u = t.uppercased()
        if u.contains("VIA ") || u.contains("@") || u.contains("BANCA") || u.contains("IBAN") {
            return false
        }
        if t.contains(" ") { return true }
        if u.contains("ITALIA") || u.contains("PERU") || u.contains("PERÙ") { return true }
        if t.contains("^") || u.contains("VASO") || u.contains("MIX") { return true }
        return false
    }

    static func splitMergedCodeAndLot(_ text: String) -> (code: String, lot: String)? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"^([A-Za-z][A-Za-z0-9._\-/]{1,28})\s*[:\|]\s*(\d{4,10})$"#,
            #"^([A-Za-z][A-Za-z0-9._\-/]{1,28})\s+(\d{4,10})$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(t.startIndex..., in: t)
            guard let m = regex.firstMatch(in: t, range: range),
                  m.numberOfRanges >= 3,
                  let cR = Range(m.range(at: 1), in: t),
                  let lR = Range(m.range(at: 2), in: t) else { continue }
            let code = String(t[cR])
            let lot = String(t[lR])
            if looksLikeArticleCode(code), looksLikeLot(lot) {
                return (code, lot)
            }
        }
        return nil
    }
}
