import Foundation
import CoreGraphics
import ImageIO
import Vision
import LabelScanningContract

public struct OCRLine: Sendable, Equatable {
    public let text: String
    public let confidence: Float

    public init(text: String, confidence: Float = 1) {
        self.text = text
        self.confidence = confidence
    }
}

public struct OCRResult: Sendable {
    public let lines: [OCRLine]

    public init(lines: [OCRLine]) {
        self.lines = lines
    }
}

/// OCR on-device: `RecognizeDocumentsRequest` (barcode disabilitati) con fallback `RecognizeTextRequest`.
public struct DocumentOCRService: Sendable {
    public init() {}

    public func recognize(imageData: Data) async throws -> OCRResult {
        guard CGImageSourceCreateWithData(imageData as CFData, nil) != nil else {
            throw LabelScanError.invalidImage
        }

        do {
            return try await recognizeDocuments(imageData: imageData)
        } catch {
            do {
                return try await recognizeTextFallback(imageData: imageData)
            } catch {
                throw LabelScanError.ocrFailed(error.localizedDescription)
            }
        }
    }

    private func recognizeDocuments(imageData: Data) async throws -> OCRResult {
        var request = RecognizeDocumentsRequest()
        request.barcodeDetectionOptions.enabled = false
        request.textRecognitionOptions.useLanguageCorrection = true
        request.textRecognitionOptions.customWords = LabelKeywordDictionary.allCustomWords

        let observations = try await request.perform(on: imageData)
        guard let document = observations.first?.document else {
            throw LabelScanError.ocrFailed("Nessun documento riconosciuto")
        }

        // Solo testo stampato — mai barcode/QR/DataMatrix (anche se presenti nell'observation).
        var lines: [OCRLine] = []
        for paragraph in document.paragraphs {
            let transcript = paragraph.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else { continue }
            for piece in transcript.components(separatedBy: .newlines) {
                let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lines.append(OCRLine(text: trimmed, confidence: 0.9))
                }
            }
        }

        if lines.isEmpty {
            let transcript = document.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                lines = transcript
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { OCRLine(text: $0, confidence: 0.85) }
            }
        }

        guard !lines.isEmpty else {
            throw LabelScanError.ocrFailed("Nessun testo estratto")
        }
        return OCRResult(lines: lines)
    }

    private func recognizeTextFallback(imageData: Data) async throws -> OCRResult {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.customWords = LabelKeywordDictionary.allCustomWords

        let observations = try await request.perform(on: imageData)
        let lines: [OCRLine] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return OCRLine(text: text, confidence: candidate.confidence)
        }

        guard !lines.isEmpty else {
            throw LabelScanError.ocrFailed("Nessun testo (fallback RecognizeTextRequest)")
        }
        return OCRResult(lines: lines)
    }
}
