import Foundation
import Vision
import UIKit

/// OCR on-device con Apple Vision — fallback quando Groq non è disponibile.
struct AppleVisionLabelLotExtractor: LabelLotExtractorProtocol, Sendable {
    func analyzeLabel(from imageData: Data, expectedIngredients: [String]) async throws -> LabelLotExtractionResult {
        let texts = try await recognizeText(from: imageData)
        let merged = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merged.isEmpty else {
            throw LabelLotError.invalidImage
        }

        let lot = LabelStampLineParser.extractLot(from: merged)
        let expiry = ExpiryDateParser.parse(from: merged)
            ?? LabelStampLineParser.parseExpiry(from: merged)
            .flatMap { LabelLotSanitizer.validateExpiry($0) }

        var audit = ["OCR locale Apple Vision", "\(texts.count) passaggi immagine"]
        if let lot { audit.append("Lotto: «\(lot)»") }
        if let expiry {
            let df = DateFormatter()
            df.dateFormat = "dd/MM/yyyy"
            df.locale = Locale(identifier: "it_IT")
            audit.append("Scadenza: \(df.string(from: expiry))")
        }

        let confidence: Double
        switch (lot != nil, expiry != nil) {
        case (true, true): confidence = 0.78
        case (true, false): confidence = 0.62
        case (false, true): confidence = 0.58
        case (false, false): confidence = 0
        }

        return LabelLotExtractionResult(
            rawText: merged,
            extractedIngredient: nil,
            extractedLotCode: lot,
            extractedExpiryDate: expiry,
            confidence: confidence,
            auditLines: audit
        )
    }

    private func recognizeText(from imageData: Data) async throws -> [String] {
        let images = await Task.detached(priority: .userInitiated) {
            GroqVisionImagePreprocessor.prepare(from: imageData)
        }.value

        var variants: [Data] = [imageData]
        if let prepared = images {
            variants = [
                prepared.stampBottomJPEG,
                prepared.fullFrameJPEG
            ]
        }

        return try await withThrowingTaskGroup(of: String.self) { group in
            for data in variants {
                group.addTask {
                    (try? await self.recognizeText(in: data)) ?? ""
                }
            }
            var lines: [String] = []
            for try await text in group where !text.isEmpty {
                lines.append(text)
            }
            return lines
        }
    }

    private func recognizeText(in imageData: Data) async throws -> String {
        guard let image = ImageProcessor.downsampledImage(
            from: imageData,
            maxPixel: PerformanceConfig.groqVisionMaxPixel
        ),
              let cgImage = image.cgImage else {
            return ""
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["it-IT", "en-US", "en-GB"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
