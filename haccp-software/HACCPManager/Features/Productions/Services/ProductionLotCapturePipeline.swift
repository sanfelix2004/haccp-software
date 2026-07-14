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

/// Pipeline unica: Foto → OCR locale + Groq in parallelo → lotto + scadenza.
struct ProductionLotCapturePipeline {
    private let labelExtractor: ResilientLabelLotExtractor

    init(labelExtractor: ResilientLabelLotExtractor? = nil) {
        self.labelExtractor = labelExtractor ?? ResilientLabelLotExtractor(
            resolvedKeys: GroqApiKeyService.resolvedKeys()
        )
    }

    func process(
        photoData: Data,
        expectedIngredientNames: [String]
    ) async throws -> ProductionLotCaptureOutcome {
        let result = try await labelExtractor.analyzeLabel(
            from: photoData,
            expectedIngredients: expectedIngredientNames
        )
        return mapOutcome(result)
    }

    func processGroqOnly(
        photoData: Data,
        expectedIngredientNames: [String]
    ) async throws -> ProductionLotCaptureOutcome {
        let groq = GroqLotExtractor(resolvedKeys: GroqApiKeyService.resolvedKeys())
        let result = try await groq.analyzeLabel(
            from: photoData,
            expectedIngredients: expectedIngredientNames
        )
        return mapOutcome(result)
    }

    /// Anteprima OCR on-device — aggiorna l'UI in ~2s mentre Groq lavora in background.
    func processLocalPreview(
        photoData: Data
    ) async -> ProductionLotCaptureOutcome? {
        guard let result = await labelExtractor.analyzeLabelLocally(from: photoData) else { return nil }
        guard result.extractedLotCode != nil || result.extractedExpiryDate != nil else { return nil }
        return mapOutcome(result, notePrefix: "Anteprima locale")
    }

    private func mapOutcome(
        _ result: LabelLotExtractionResult,
        notePrefix: String? = nil
    ) -> ProductionLotCaptureOutcome {
        var outcome = ProductionLotCaptureOutcome(
            rawText: result.rawText,
            lotCode: result.extractedLotCode?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            ingredientName: result.extractedIngredient?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            expiryDate: result.extractedExpiryDate,
            confidence: result.confidence,
            lotParseAudit: result.auditLines,
            analysisNote: analysisNote(for: result)
        )
        if let notePrefix, outcome.analysisNote == nil {
            outcome = ProductionLotCaptureOutcome(
                rawText: outcome.rawText,
                lotCode: outcome.lotCode,
                ingredientName: outcome.ingredientName,
                expiryDate: outcome.expiryDate,
                confidence: outcome.confidence,
                lotParseAudit: outcome.lotParseAudit,
                analysisNote: notePrefix
            )
        }
        return outcome
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
