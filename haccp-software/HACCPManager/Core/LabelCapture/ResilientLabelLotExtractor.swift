import Foundation

/// Groq Vision come primario, Apple Vision in parallelo — restituisce il primo risultato utile.
struct ResilientLabelLotExtractor: LabelLotExtractorProtocol, Sendable {
    private let primary: GroqLotExtractor
    private let fallback = AppleVisionLabelLotExtractor()

    init(resolvedKeys: (primary: String, fallback: String?)) {
        self.primary = GroqLotExtractor(resolvedKeys: resolvedKeys)
    }

    func analyzeLabel(from imageData: Data, expectedIngredients: [String]) async throws -> LabelLotExtractionResult {
        let hasGroq = GroqApiKeyService.hasAnyKey()

        return try await withThrowingTaskGroup(of: LabelLotExtractionResult.self) { group in
            group.addTask {
                try await self.fallback.analyzeLabel(from: imageData, expectedIngredients: expectedIngredients)
            }
            if hasGroq {
                group.addTask {
                    try await self.primary.analyzeLabel(from: imageData, expectedIngredients: expectedIngredients)
                }
            }

            var collected: [LabelLotExtractionResult] = []
            while let result = try await group.next() {
                collected.append(result)
                if Self.isComplete(result) {
                    group.cancelAll()
                    return result
                }
                if collected.count >= (hasGroq ? 2 : 1) {
                    group.cancelAll()
                    return Self.merge(collected)
                }
            }

            if let merged = collected.isEmpty ? nil : Self.merge(collected) {
                return merged
            }
            throw GroqLotError.missingApiKey
        }
    }

    /// Anteprima rapida OCR on-device (~2s) — aggiorna subito l'UI.
    func analyzeLabelLocally(from imageData: Data) async -> LabelLotExtractionResult? {
        try? await fallback.analyzeLabel(from: imageData, expectedIngredients: [])
    }

    private static func isComplete(_ result: LabelLotExtractionResult) -> Bool {
        let hasLot = result.extractedLotCode?.isEmpty == false
        let hasExpiry = result.extractedExpiryDate != nil
        return hasLot && hasExpiry && result.confidence >= 0.72
    }

    private static func merge(_ results: [LabelLotExtractionResult]) -> LabelLotExtractionResult {
        guard let first = results.first else {
            return LabelLotExtractionResult(
                rawText: "",
                extractedIngredient: nil,
                extractedLotCode: nil,
                extractedExpiryDate: nil,
                confidence: 0,
                auditLines: []
            )
        }
        return results.dropFirst().reduce(first) { partial, next in
            LabelLotExtractionResult(
                rawText: [partial.rawText, next.rawText].filter { !$0.isEmpty }.joined(separator: "\n"),
                extractedIngredient: partial.extractedIngredient ?? next.extractedIngredient,
                extractedLotCode: preferredLot(partial.extractedLotCode, next.extractedLotCode),
                extractedExpiryDate: partial.extractedExpiryDate ?? next.extractedExpiryDate,
                confidence: max(partial.confidence, next.confidence),
                auditLines: partial.auditLines + next.auditLines
            )
        }
    }

    private static func preferredLot(_ a: String?, _ b: String?) -> String? {
        guard let a else { return b }
        guard let b else { return a }
        if a.hasPrefix("L"), !b.hasPrefix("L"), b.caseInsensitiveCompare(String(a.dropFirst())) == .orderedSame { return a }
        if b.hasPrefix("L"), !a.hasPrefix("L"), a.caseInsensitiveCompare(String(b.dropFirst())) == .orderedSame { return b }
        return a.count >= b.count ? a : b
    }
}
