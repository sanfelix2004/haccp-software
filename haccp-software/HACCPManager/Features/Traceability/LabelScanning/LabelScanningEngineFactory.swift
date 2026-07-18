import Foundation
import LabelScanningContract
import LabelScannerV2

enum LabelScanningEngineFactory {
    static func make(selection: LabelScanEngineSelection = .current) -> any LabelScanningEngine {
        switch selection {
        case .v1:
            return V1LabelScanningEngineAdapter()
        case .v2:
            return LabelScannerV2Engine()
        }
    }
}

enum LabelScanResultBridge {
    static func toCaptureOutcome(_ result: LabelScanResult) -> ProductionLotCaptureOutcome {
        var note: String?
        if let hint = result.recoveryHint, !hint.isEmpty {
            note = hint
        } else if result.needsManualConfirmation {
            note = "Lettura completata ma incerta — controlla lotto e scadenza sull'etichetta prima di confermare."
        }
        return ProductionLotCaptureOutcome(
            rawText: result.rawRecognizedText.joined(separator: "\n"),
            lotCode: result.lotto,
            ingredientName: nil,
            expiryDate: result.scadenza,
            confidence: result.confidence,
            lotParseAudit: [
                "engine=\(LabelScanEngineSelection.current.title)",
                result.needsManualConfirmation ? "needsManualConfirmation=true" : "needsManualConfirmation=false",
                result.recoveryHint != nil ? "cropRetryHint=true" : "cropRetryHint=false"
            ],
            analysisNote: note
        )
    }
}
