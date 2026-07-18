import Foundation
import LabelScanningContract

/// Adapter minimale: avvolge la pipeline V1 esistente senza modificarla.
struct V1LabelScanningEngineAdapter: LabelScanningEngine {
    func scan(imageData: Data) async throws -> LabelScanResult {
        let outcome = try await LottoFotoService().extractLot(from: imageData)
        let lines = outcome.rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let needsManual = outcome.confidence < 0.72
            || outcome.lotCode == nil
            || outcome.expiryDate == nil
            || outcome.analysisNote != nil

        return LabelScanResult(
            lotto: outcome.lotCode,
            scadenza: outcome.expiryDate,
            scadenzaRawText: nil,
            confidence: outcome.confidence,
            rawRecognizedText: lines,
            needsManualConfirmation: needsManual
        )
    }
}
