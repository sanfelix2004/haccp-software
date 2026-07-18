import Foundation
import LabelScanningContract

/// Motore V2 on-device: Vision document OCR → Foundation Models (se disponibile) → merge con regex.
///
/// Se la prima lettura è incompleta/incerta, ritaglia zone tipiche dello stampo e rianalizza.
public struct LabelScannerV2Engine: LabelScanningEngine {
    private let ocr: DocumentOCRService
    private let semanticInterpreter: any LabelSemanticInterpreter
    private let regexInterpreter: RegexFallbackInterpreter
    private let sanity: ExpirySanityValidator

    public static let cropRecoveryHintIT =
        "Lettura incompleta. Ritaglia lo stampo (lotto/scadenza), avvicinalo e riprova la foto."

    public init(
        ocr: DocumentOCRService = DocumentOCRService(),
        semanticInterpreter: any LabelSemanticInterpreter = FoundationModelsLabelInterpreter(),
        regexInterpreter: RegexFallbackInterpreter = RegexFallbackInterpreter(),
        sanity: ExpirySanityValidator = ExpirySanityValidator()
    ) {
        self.ocr = ocr
        self.semanticInterpreter = semanticInterpreter
        self.regexInterpreter = regexInterpreter
        self.sanity = sanity
    }

    public func scan(imageData: Data) async throws -> LabelScanResult {
        try await scan(imageData: imageData, allowCropRetry: true)
    }

    /// Interpretazione solo testo (test unitari / pipeline senza Vision).
    public func interpretOCRLines(_ lines: [String]) async -> LabelScanResult {
        await interpret(lines: lines, imageData: Data())
    }

    private func scan(imageData: Data, allowCropRetry: Bool) async throws -> LabelScanResult {
        guard !imageData.isEmpty else { throw LabelScanError.invalidImage }

        let ocrResult = try await ocr.recognize(imageData: imageData)
        let lines = ocrResult.lines.map(\.text)
        var best = await interpret(lines: lines, imageData: imageData)

        guard allowCropRetry, shouldRetryWithCrops(best) else {
            return attachRecoveryHintIfNeeded(best, didAttemptCrops: false)
        }

        let crops = LabelImageCropper.makeRetryCrops(from: imageData)
        for cropData in crops {
            do {
                let candidate = try await scan(imageData: cropData, allowCropRetry: false)
                if score(candidate) > score(best) {
                    best = candidate
                }
                if isStrongResult(best) { break }
            } catch {
                // Ritaglio senza testo utile: passa al successivo.
                continue
            }
        }

        return attachRecoveryHintIfNeeded(best, didAttemptCrops: !crops.isEmpty)
    }

    private func shouldRetryWithCrops(_ result: LabelScanResult) -> Bool {
        result.lotto == nil || result.scadenza == nil || result.confidence < 0.72
    }

    private func isStrongResult(_ result: LabelScanResult) -> Bool {
        result.lotto != nil && result.scadenza != nil && result.confidence >= 0.72
    }

    private func score(_ result: LabelScanResult) -> Double {
        var value = result.confidence
        if result.lotto != nil { value += 1.0 }
        if result.scadenza != nil { value += 1.0 }
        if result.lotto != nil, result.scadenza != nil { value += 0.5 }
        return value
    }

    private func attachRecoveryHintIfNeeded(
        _ result: LabelScanResult,
        didAttemptCrops: Bool
    ) -> LabelScanResult {
        let incomplete = result.lotto == nil || result.scadenza == nil
        guard didAttemptCrops, incomplete else { return result }
        return LabelScanResult(
            lotto: result.lotto,
            scadenza: result.scadenza,
            scadenzaRawText: result.scadenzaRawText,
            confidence: result.confidence,
            rawRecognizedText: result.rawRecognizedText,
            needsManualConfirmation: true,
            recoveryHint: Self.cropRecoveryHintIT
        )
    }

    private func interpret(lines: [String], imageData: Data) async -> LabelScanResult {
        let regex = regexInterpreter.interpret(lines: lines)

        var semantic: InterpretedLabelFields?
        if semanticInterpreter.isAvailable {
            semantic = try? await semanticInterpreter.interpret(imageData: imageData, ocrLines: lines)
        }

        let merged = merge(semantic: semantic, regex: regex, ocrLines: lines)
        return finalize(merged, lines: lines, usedFoundationModels: semantic != nil)
    }

    /// Il regex ancora i formati strutturali nell'OCR; FM riempie i buchi senza sovrascrivere evidenze chiare.
    private func merge(
        semantic: InterpretedLabelFields?,
        regex: InterpretedLabelFields,
        ocrLines: [String]
    ) -> InterpretedLabelFields {
        let ocrBlob = ocrLines.joined(separator: "\n").uppercased()

        let lotto: String? = {
            if let regexLot = regex.lotto { return regexLot }
            if let semanticLot = semantic?.lotto.flatMap({ LotNormalizer.normalize($0) }) {
                return semanticLot
            }
            return nil
        }()

        let expiry: (date: Date?, raw: String?) = {
            // Se l'OCR contiene MM/YYYY (o simile) e regex l'ha letto, vince sul modello.
            if let regexDate = regex.scadenza, let raw = regex.scadenzaRawText {
                let compactRaw = raw.replacingOccurrences(of: " ", with: "")
                if ocrBlob.contains(compactRaw.uppercased())
                    || ocrLooksLikeMonthYear(ocrBlob)
                    || regex.confidence >= 0.5 {
                    return (regexDate, raw)
                }
            }
            if let semanticDate = semantic?.scadenza {
                // Scarta allucinazioni FM non supportate dal testo OCR.
                if let raw = semantic?.scadenzaRawText,
                   !raw.isEmpty,
                   ocrSupportsDate(raw, ocrBlob: ocrBlob) {
                    return (semanticDate, raw)
                }
                if regex.scadenza == nil {
                    return (semanticDate, semantic?.scadenzaRawText)
                }
            }
            return (regex.scadenza, regex.scadenzaRawText)
        }()

        var confidence = regex.confidence
        if semantic != nil { confidence = max(confidence, semantic!.confidence * 0.85) }
        if lotto != nil, expiry.date != nil { confidence = max(confidence, 0.75) }

        return InterpretedLabelFields(
            lotto: lotto,
            scadenza: expiry.date,
            scadenzaRawText: expiry.raw,
            confidence: min(confidence, 0.95)
        )
    }

    private func ocrLooksLikeMonthYear(_ ocr: String) -> Bool {
        ocr.range(of: #"\b(0?[1-9]|1[0-2])[\/\-\.]\d{2,4}\b"#, options: .regularExpression) != nil
    }

    private func ocrSupportsDate(_ raw: String, ocrBlob: String) -> Bool {
        let normalized = raw
            .uppercased()
            .replacingOccurrences(of: "-", with: "/")
            .replacingOccurrences(of: ".", with: "/")
        if ocrBlob.contains(normalized) { return true }
        // ISO → cerca anno/mese nel blob
        if normalized.count >= 7 {
            let year = String(normalized.prefix(4))
            if ocrBlob.contains(year) { return true }
        }
        return false
    }

    private func finalize(
        _ fields: InterpretedLabelFields,
        lines: [String],
        usedFoundationModels: Bool
    ) -> LabelScanResult {
        let cleanedLot = LotNormalizer.normalize(fields.lotto)
        let saneExpiry = sanity.validate(fields.scadenza)
        let raw = saneExpiry == nil ? nil : fields.scadenzaRawText
        let lowConfidence = fields.confidence < 0.72
        let incomplete = cleanedLot == nil || saneExpiry == nil
        let needsManual = !usedFoundationModels || lowConfidence || incomplete

        return LabelScanResult(
            lotto: cleanedLot,
            scadenza: saneExpiry,
            scadenzaRawText: raw,
            confidence: fields.confidence,
            rawRecognizedText: lines,
            needsManualConfirmation: needsManual
        )
    }
}
