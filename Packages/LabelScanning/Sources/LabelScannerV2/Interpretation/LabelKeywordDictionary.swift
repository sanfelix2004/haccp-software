import Foundation

/// Keyword IT/EN per identificare candidati lotto/scadenza (case-insensitive).
public enum LabelKeywordDictionary {
    public static let lotKeywords: [String] = [
        "LOTTO", "LOT", "LOT N", "L.", "L:", "BATCH", "BATCH NUMBER", "BATCH NO",
        "B.N.", "BN", "PARTITA", "N° LOTTO", "COD LOTTO", "CODICE LOTTO",
        "LOT NUMBER", "LOT NO"
    ]

    public static let expiryKeywords: [String] = [
        "SCAD", "SCADENZA", "SCADE", "EXP", "EXP DATE", "EXPIRY", "EXPIRATION",
        "BEST BEFORE", "BEST BEFORE END", "BBE", "BB", "DA CONSUMARSI ENTRO",
        "DA CONSUMARSI PREFERIBILMENTE ENTRO", "USE BY", "SELL BY",
        "ENTRO IL", "FINO AL", "TMC", "PREFERIBILMENTE ENTRO"
    ]

    /// Parole da NON usare come lotto (rumore packaging / etichetta).
    public static let reservedNoise: Set<String> = [
        "NUMBER", "BATCH", "LOT", "LOTTO", "BEST", "BEFORE", "END", "SELL", "BY",
        "USE", "EXP", "EXPIRY", "SCAD", "SCADENZA", "LATTE", "YOGURT", "GRECO",
        "BIANCO", "FRESCO", "NUMBER:", "NO", "NR", "NON", "VENDIBILE", "SINGOLARMENTE",
        "CONSUMARSI", "PREFERIBILMENTE", "ENTRO"
    ]

    /// Frasi packaging tipiche da scartare anche se OCR le attacca senza spazi.
    public static let packagingNoiseSubstrings: [String] = [
        "VENDIBILE", "SINGOLAR", "CONSUMARSI", "PREFERIBILMENTE",
        "NONVENDIBILE", "INGREDIENTI", "VALORINUTRIZIONALI", "CONSERVARE",
        "PRODOTTOIN", "DACONSUMARSI"
    ]

    public static func isPackagingNoise(_ value: String) -> Bool {
        let upper = value.uppercased().replacingOccurrences(of: " ", with: "")
        if reservedNoise.contains(upper) { return true }
        return packagingNoiseSubstrings.contains { upper.contains($0) }
    }

    public static var allCustomWords: [String] {
        Array(Set(lotKeywords + expiryKeywords)).sorted()
    }

    public static func isLotContext(_ line: String) -> Bool {
        let upper = line.uppercased()
        return lotKeywords.contains { upper.contains($0) }
    }

    public static func isExpiryContext(_ line: String) -> Bool {
        let upper = line.uppercased()
        return expiryKeywords.contains { upper.contains($0) }
    }
}
