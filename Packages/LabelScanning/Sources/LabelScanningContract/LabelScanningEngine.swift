import Foundation

/// Contratto comune per motori di lettura lotto/scadenza da foto etichetta.
public protocol LabelScanningEngine: Sendable {
    func scan(imageData: Data) async throws -> LabelScanResult
}

public struct LabelScanResult: Sendable, Equatable {
    public let lotto: String?
    public let scadenza: Date?
    /// Testo grezzo della data come letto (es. `"11/2027"`, `"31 AGO 2026"`).
    public let scadenzaRawText: String?
    public let confidence: Double
    public let rawRecognizedText: [String]
    /// `true` quando il risultato richiede conferma utente (fallback regex, AI assente, bassa confidenza).
    public let needsManualConfirmation: Bool
    /// Suggerimento UX se la lettura resta incompleta dopo i ritagli automatici (es. ritaglia lo stampo).
    public let recoveryHint: String?

    public init(
        lotto: String?,
        scadenza: Date?,
        scadenzaRawText: String?,
        confidence: Double,
        rawRecognizedText: [String],
        needsManualConfirmation: Bool,
        recoveryHint: String? = nil
    ) {
        self.lotto = lotto
        self.scadenza = scadenza
        self.scadenzaRawText = scadenzaRawText
        self.confidence = confidence
        self.rawRecognizedText = rawRecognizedText
        self.needsManualConfirmation = needsManualConfirmation
        self.recoveryHint = recoveryHint
    }
}

public enum LabelScanError: Error, Sendable, LocalizedError {
    case invalidImage
    case ocrFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Immagine non valida per la scansione etichetta."
        case .ocrFailed(let detail):
            return "OCR fallito: \(detail)"
        }
    }
}
