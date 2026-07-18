import Foundation
import FoundationModels

/// Interpretazione semantica on-device via Foundation Models (guided generation).
///
/// Nota SDK 26.4: l'input multimodale `Attachment(CGImage)` non è ancora esposto
/// nell'API pubblica; passiamo il testo OCR grezzo + istruzioni strutturate.
/// Quando l'SDK aggiungerà gli attachment immagine, il punto di iniezione è `interpret`.
public struct FoundationModelsLabelInterpreter: LabelSemanticInterpreter {
    public init() {}

    public var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        default:
            return false
        }
    }

    public func interpret(imageData: Data, ocrLines: [String]) async throws -> InterpretedLabelFields {
        guard isAvailable else {
            throw InterpreterUnavailable.appleIntelligenceUnavailable
        }

        let ocrBlock = ocrLines.joined(separator: "\n")
        let session = LanguageModelSession(instructions: Self.systemInstructions)

        let response = try await session.respond(generating: GenerableLabelExtraction.self) {
            """
            Estrai LOTTO e SCADENZA dal testo OCR di un'etichetta alimentare.
            Ignora marchi, nomi prodotto, ingredienti, EAN/barcode.
            Casi tipici:
            - "31/08/26" / "31.08.2026" / "310826" / "08/31/26"(US) → ISO data
            - "08/2026" / "0826" / "AGO 26" → ultimo giorno del mese
            - "31/08/26" + "08:18H-FYB" → lotto 08:18H-FYB
            - "Best Before End: 11/2027" + "Batch number: 44464" → lotto 44464
            - "26.07.2026" + "L. 26F082/B" → lotto L.26F082/B
            - "J11LR233 12/2028 L1" → lotto J11LR233, scadenza fine 2028-12 (NON L1, NON date inventate)
            - "(Z) Z63648" sotto Lotto → lotto (Z)Z63648 (uova / centro imballaggio)
            - Prefissi lotto: L. L: LOT LOTTO BATCH B.N. — ripulire il prefisso
            - Mai usare come lotto: number, batch, LATTE, LATTY, YOGURT, GRECO, L1 se c'è un codice più lungo sulla riga

            OCR:
            \(ocrBlock)
            """
        }

        let content = response.content
        let lotto = content.lotto.flatMap { $0.isEmpty || $0.lowercased() == "null" ? nil : $0 }
        let raw = content.scadenza.flatMap { $0.isEmpty || $0.lowercased() == "null" ? nil : $0 }
        let date = raw.flatMap { Self.parseISODate($0) }
        let confidence = min(max(content.confidence, 0), 1)

        return InterpretedLabelFields(
            lotto: lotto,
            scadenza: date,
            scadenzaRawText: raw,
            confidence: confidence
        )
    }

    private static let systemInstructions = """
    Sei un estrattore HACCP. Restituisci solo lotto industriale e data di scadenza.
    Date sempre in ISO YYYY-MM-DD (per MM/YYYY usa l'ultimo giorno del mese).
    Non inventare dati: se manca, lascia null / stringa vuota e confidence bassa.
    """

    private static func parseISODate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: trimmed) { return date }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: trimmed)
    }
}

enum InterpreterUnavailable: Error {
    case appleIntelligenceUnavailable
}

@Generable
struct GenerableLabelExtraction {
    @Guide(description: "Codice lotto industriale, o null se assente")
    var lotto: String?

    @Guide(description: "Scadenza in ISO YYYY-MM-DD, o null se assente")
    var scadenza: String?

    @Guide(description: "Confidenza 0...1")
    var confidence: Double
}
