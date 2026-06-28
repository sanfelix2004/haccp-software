import Foundation

/// Legame HACCP immutabile: sessione produzione ↔ foto etichetta ↔ codice lotto.
struct ProductionLotBinding: Equatable, Sendable {
    let produzioneBatchId: UUID
    let productionId: UUID
    let photoId: UUID?
    let lotCode: String
    let registeredAt: Date
}

/// Esito della pipeline di acquisizione lotto da foto etichetta.
struct ProductionLotCaptureOutcome: Sendable {
    let rawText: String
    let lotCode: String?
    let ingredientName: String?
    let expiryDate: Date?
    let confidence: Double
    let lotParseAudit: [String]
    let analysisNote: String?
    var isLotAutoRegistered: Bool { lotCode?.isEmpty == false }
    var isExpiryFromLabel: Bool { expiryDate != nil }

    init(
        rawText: String,
        lotCode: String?,
        ingredientName: String?,
        expiryDate: Date?,
        confidence: Double,
        lotParseAudit: [String],
        analysisNote: String? = nil
    ) {
        self.rawText = rawText
        self.lotCode = lotCode
        self.ingredientName = ingredientName
        self.expiryDate = expiryDate
        self.confidence = confidence
        self.lotParseAudit = lotParseAudit
        self.analysisNote = analysisNote
    }
}

/// Pipeline unica: Foto → Groq Vision → lotto + scadenza.
struct ProductionLotCapturePipeline {
    private let labelExtractor: any LabelLotExtractorProtocol

    init(labelExtractor: (any LabelLotExtractorProtocol)? = nil) {
        if let labelExtractor {
            self.labelExtractor = labelExtractor
        } else {
            let key = SettingsStorageService.shared.haccp.groqApiKey ?? ""
            self.labelExtractor = GroqLotExtractor(apiKey: key)
        }
    }

    func process(
        photoData: Data,
        expectedIngredientNames: [String]
    ) async throws -> ProductionLotCaptureOutcome {
        let result = try await labelExtractor.analyzeLabel(
            from: photoData,
            expectedIngredients: expectedIngredientNames
        )
        return ProductionLotCaptureOutcome(
            rawText: result.rawText,
            lotCode: result.extractedLotCode?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            ingredientName: result.extractedIngredient?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            expiryDate: result.extractedExpiryDate,
            confidence: result.confidence,
            lotParseAudit: result.auditLines,
            analysisNote: analysisNote(for: result)
        )
    }

    private func analysisNote(for result: LabelLotExtractionResult) -> String? {
        let hasLot = result.extractedLotCode?.isEmpty == false
        let hasExpiry = result.extractedExpiryDate != nil
        let lowConfidence = result.confidence < GroqLotExtractor.manualVerificationThreshold

        if hasLot && hasExpiry {
            if lowConfidence {
                return "Lettura completata ma incerta — controlla lotto e scadenza sull'etichetta prima di confermare."
            }
            return nil
        }
        if hasLot && !hasExpiry {
            return "Lotto letto. Scadenza non trovata — inseriscila manualmente se serve."
        }
        if !hasLot && hasExpiry {
            return "Scadenza letta. Lotto non trovato — inseriscilo manualmente."
        }
        return "Lettura automatica non riuscita. Inserisci lotto e scadenza manualmente."
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
