import Foundation

public struct InterpretedLabelFields: Sendable, Equatable {
    public let lotto: String?
    public let scadenza: Date?
    public let scadenzaRawText: String?
    public let confidence: Double

    public init(lotto: String?, scadenza: Date?, scadenzaRawText: String?, confidence: Double) {
        self.lotto = lotto
        self.scadenza = scadenza
        self.scadenzaRawText = scadenzaRawText
        self.confidence = confidence
    }
}

/// Punto di estensione per interpretazione semantica (Foundation Models oggi; cloud in futuro).
public protocol LabelSemanticInterpreter: Sendable {
    var isAvailable: Bool { get }
    func interpret(imageData: Data, ocrLines: [String]) async throws -> InterpretedLabelFields
}
