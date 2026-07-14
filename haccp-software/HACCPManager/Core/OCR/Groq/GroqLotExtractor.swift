import Foundation

/// Lettura etichetta via Groq Vision — ritaglio area stampa + multi-immagine + validazione locale.
struct GroqLotExtractor: LabelLotExtractorProtocol, Sendable {
    let apiKey: String
    let fallbackApiKey: String?

    private static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    /// Unico modello vision attualmente disponibile su Groq (Maverick rimosso dal catalogo).
    private static let model = "meta-llama/llama-4-scout-17b-16e-instruct"
    /// Riserva multimodale Groq se Scout non è disponibile sulla chiave.
    private static let fallbackModel = "qwen/qwen3.6-27b"

    private static var visionModelChain: [String] {
        [model, fallbackModel]
    }

    /// Sotto questa soglia l'operatore deve verificare manualmente.
    static let manualVerificationThreshold = 0.85

    init(apiKey: String, fallbackApiKey: String? = nil) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = fallbackApiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallback, !fallback.isEmpty, fallback != self.apiKey {
            self.fallbackApiKey = fallback
        } else {
            self.fallbackApiKey = nil
        }
    }

    init(resolvedKeys: (primary: String, fallback: String?)) {
        self.init(apiKey: resolvedKeys.primary, fallbackApiKey: resolvedKeys.fallback)
    }

    func analyzeLabel(from imageData: Data, expectedIngredients: [String]) async throws -> LabelLotExtractionResult {
        guard !apiKey.isEmpty || !(fallbackApiKey ?? "").isEmpty else {
            throw GroqLotError.missingApiKey
        }

        let images = await Task.detached(priority: .userInitiated) {
            GroqVisionImagePreprocessor.prepare(from: imageData)
                ?? Self.fallbackSingleImage(from: imageData)
        }.value

        var audit = [
            "Groq \(Self.model)",
            "Varianti immagine: ritaglio alto/basso + invertiti + panorama",
            "Risoluzione max \(Int(PerformanceConfig.groqVisionMaxPixel))px"
        ]

        var parsed = try await runPrimaryPass(
            images: images,
            expectedIngredients: expectedIngredients,
            audit: &audit
        )
        var issues = GroqLabelValidator.issues(
            lot: parsed.lot,
            expiry: parsed.expiry,
            rawContext: parsed.rawPayload
        )

        let primaryConfidence = GroqLabelResponseParser.confidence(for: parsed)
        if parsed.lot != nil, parsed.expiry != nil, primaryConfidence >= 0.85, issues.isEmpty {
            audit.append("Lettura completa al primo passaggio")
            return buildResult(parsed: parsed, audit: audit)
        }

        if GroqLabelValidator.shouldRetryLot(issues) || GroqLabelValidator.shouldRetryLotPrecision(parsed.lot, rawContext: parsed.rawPayload) {
            audit.append("Retry lotto mirato")
            let lotPass = try await chatCompletion(
                jpegVariants: limitedVariants([
                    images.stampBottomJPEG,
                    images.stampBottomInvertedJPEG
                ]),
                system: Self.systemPrompt,
                prompt: Self.lotOnlyPrompt
            )
            parsed = parsed.merging(GroqLabelResponseParser.parse(lotPass))
            issues = GroqLabelValidator.issues(
                lot: parsed.lot,
                expiry: parsed.expiry,
                rawContext: parsed.rawPayload
            )
        }

        if GroqLabelValidator.shouldRetryExpiry(issues) {
            audit.append("Retry scadenza")
            let expiryPass = try await chatCompletion(
                jpegVariants: limitedVariants([images.stampBottomJPEG, images.fullFrameJPEG]),
                system: Self.systemPrompt,
                prompt: Self.expiryOnlyPrompt
            )
            parsed = parsed.merging(GroqLabelResponseParser.parse(expiryPass))
            issues = GroqLabelValidator.issues(
                lot: parsed.lot,
                expiry: parsed.expiry,
                rawContext: parsed.rawPayload
            )
        }

        if issues.contains(where: { $0 == .missingLot || $0 == .missingExpiry }),
           parsed.lot == nil || parsed.expiry == nil {
            audit.append("Verifica finale")
            let verifyRaw = try await chatCompletion(
                jpegVariants: limitedVariants([
                    images.stampBottomJPEG,
                    images.fullFrameJPEG
                ]),
                system: Self.systemPrompt,
                prompt: Self.verifyPrompt(
                    lot: parsed.lot,
                    expiry: parsed.expiry
                )
            )
            parsed = parsed.merging(GroqLabelResponseParser.parse(verifyRaw))
        }

        let confidence = GroqLabelResponseParser.confidence(for: parsed)
        audit.append(contentsOf: parsed.audit)
        if confidence < Self.manualVerificationThreshold {
            audit.append("Affidabilità bassa — verifica lotto e scadenza a occhio")
        }

        return buildResult(parsed: parsed, audit: audit, confidence: confidence)
    }

    private func buildResult(
        parsed: GroqLabelResponseParser.Parsed,
        audit: [String],
        confidence: Double? = nil
    ) -> LabelLotExtractionResult {
        let score = confidence ?? GroqLabelResponseParser.confidence(for: parsed)
        return LabelLotExtractionResult(
            rawText: parsed.rawPayload,
            extractedIngredient: nil,
            extractedLotCode: parsed.lot,
            extractedExpiryDate: parsed.expiry,
            confidence: score,
            auditLines: audit
        )
    }

    private func limitedVariants(_ variants: [Data], maxCount: Int = 2) -> [Data] {
        Array(variants.prefix(maxCount))
    }

    // MARK: - Passes

    private func runPrimaryPass(
        images: GroqVisionImagePreprocessor.PreparedImages,
        expectedIngredients: [String],
        audit: inout [String]
    ) async throws -> GroqLabelResponseParser.Parsed {
        let variants = limitedVariants([
            images.stampBottomJPEG,
            images.fullFrameJPEG
        ])
        let raw = try await chatCompletion(
            jpegVariants: variants,
            system: Self.systemPrompt,
            prompt: Self.primaryPrompt(expectedIngredients: expectedIngredients)
        )
        return GroqLabelResponseParser.parse(raw)
    }

    private static func fallbackSingleImage(from data: Data) -> GroqVisionImagePreprocessor.PreparedImages {
        let jpeg = ImageProcessor.preparedJPEGData(
            from: data,
            maxPixel: PerformanceConfig.groqVisionMaxPixel,
            quality: PerformanceConfig.groqVisionJPEGQuality
        ) ?? data
        return GroqVisionImagePreprocessor.PreparedImages(
            stampFocusJPEG: jpeg,
            stampBottomJPEG: jpeg,
            stampInvertedJPEG: jpeg,
            stampBottomInvertedJPEG: jpeg,
            fullFrameJPEG: jpeg
        )
    }

    // MARK: - Prompts

    private static let jsonOutputSchema = """
    {
      "lotto_found": boolean,
      "lotto": "EXACT_LOT_AS_PRINTED" or null,
      "raw_stamp_line": "verbatim stamp text line" or null,
      "expiration_found": boolean,
      "expiration_date": "YYYY-MM-DD" or null,
      "expiration_type": "perentoria" or "tmc" or null,
      "confidence_score": "high" or "medium" or "low"
    }
    """

    private static let systemPrompt = """
    You are a highly precise JSON extractor for HACCP food safety systems. Your sole task is to analyze printed text visible in food label photos and extract the LOT NUMBER (Lotto) and EXPIRATION DATE (Scadenza).

    RULES FOR EXTRACTION:

    1. EXPIRATION DATE (Scadenza / TMC):
    - Look for keywords: "Da consumarsi entro", "Entro il", "Best before", "EXP", "Expiry", "TMC", "Scad", "Sca", "BB", "Use by", "Consumare preferibilmente entro".
    - Normalize ANY date format (GG/MM/AAAA, GG.MM.AA, GG-MM-AA, MM/AAAA, or text like "03 AGO 26", "26NOV 2025", "03 AUG 26") into ISO: "YYYY-MM-DD".
    - If only Month and Year (e.g. "08/2026"), set to LAST day of that month ("2026-08-31").
    - CRITICAL: "23/08/2026 06:08" → "2026-08-23" — IGNORE time HH:MM (not a date).
    - "SELL BY 09/02" or "USE BY 09/02" → European DD/MM: 9 February; infer year from context (NOT September 2002).
    - expiration_type: "perentoria" if "entro il" / "use by" / "sell by"; "tmc" if "preferibilmente" / "best before".

    2. LOT NUMBER (Lotto) — CRITICAL ACCURACY:
    - Copy the lot EXACTLY as printed on the stamp, character by character. Do NOT drop leading letters.
    - "LOT 272019" → lotto "272019" (digits after LOT word). NEVER use label words (SELL, BY, BEST, BEFORE) as lot.
    - If the stamp shows "L9330 B8" or "L9330B8", output "L9330B8" (keep the leading L, remove spaces only).
    - If the stamp shows "L6036BH099" or "L52400V757", keep the full code including the initial L.
    - ONLY strip label WORDS like "Lotto:", "Lot:", "Batch:", "Partita:" — never strip L when it is part of the code.
    - Do NOT confuse production time (00:09, 06:08) with lot or expiry.
    - Matrix print on jar lids / dark backgrounds: read every character carefully (L vs 1, O vs 0, V vs Y).
    - Put the full visible stamp line in raw_stamp_line (e.g. "L9330 B8 00:09").

    3. OCR ERROR CORRECTION:
    - Fix typos: "o"/"O" → "0" in dates, "I"/"l" → "1" only when clearly wrong in dates.
    - In lot codes, preserve letters; fix Y→V only when context suggests matrix misprint.

    OUTPUT: ONLY a valid JSON object. No markdown, greetings, or explanations. Missing/unreadable → null and boolean false.
    Schema:
    \(jsonOutputSchema)
    """

    private static func primaryPrompt(expectedIngredients: [String]) -> String {
        var lines = [
            "Image 1 = bottom stamp zoom (jar lid / base). Image 2 = top stamp zoom. Image 3 = full label.",
            "Extract lot and expiry per system rules. Preserve every character of the lot code.",
            "Output ONLY JSON: lotto_found, lotto, raw_stamp_line, expiration_found, expiration_date, expiration_type, confidence_score."
        ]
        if let first = expectedIngredients.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !first.isEmpty {
            lines.insert("Expected product: \(first.prefix(48)).", at: 1)
        }
        return lines.joined(separator: "\n")
    }

    private static let lotOnlyPrompt = """
    LOT NUMBER only from matrix print on lid or label stamp.
    Set expiration_found: false, expiration_date: null, expiration_type: null.
    CRITICAL: keep leading L when printed (L9330 B8 → L9330B8, L6036BH099 → L6036BH099).
    Ignore production time after the lot (00:09, 06:08 are NOT part of the lot).
    Fill raw_stamp_line with the verbatim stamp line.
    Full JSON with all seven fields.
    """

    private static let expiryOnlyPrompt = """
    EXPIRATION DATE / TMC only. Set lotto_found: false, lotto: null.
    Ignore production time (06:08 is not a date). "23/08/2026 06:08" → "2026-08-23".
    "SELL BY 09/02" → DD/MM European: 9 February (infer plausible year), NOT Sep 2002.
    MM/YYYY → last day of month in ISO.
    Full JSON with all six fields.
    """

    private static func verifyPrompt(lot: String?, expiry: Date?) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB")
        df.dateFormat = "yyyy-MM-dd"
        let lotText = lot ?? "null"
        let expiryText = expiry.map { df.string(from: $0) } ?? "null"
        return """
        Verify in the image (check bottom stamp / jar lid carefully):
        - proposed lot: \(lotText)
        - proposed expiration: \(expiryText)
        If lot is missing leading L but stamp shows L (e.g. L9330 B8), fix it. Preserve exact characters. Full JSON in standard schema.
        """
    }

    // MARK: - HTTP

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    private func chatCompletion(
        jpegVariants: [Data],
        system: String,
        prompt: String,
        model: String = GroqLotExtractor.model
    ) async throws -> String {
        let keys = orderedKeysForRequest()
        guard !keys.isEmpty else { throw GroqLotError.missingApiKey }

        let models = await resolvedModelCandidates(preferred: model, apiKey: keys[0])
        var lastModelError: GroqLotError?
        var lastAuthError: GroqLotError?

        modelLoop: for candidate in models {
            for key in keys {
                do {
                    return try await performChatCompletion(
                        apiKey: key,
                        jpegVariants: jpegVariants,
                        system: system,
                        prompt: prompt,
                        model: candidate
                    )
                } catch let error as GroqLotError {
                    switch error {
                    case .apiError(let code, let detail)
                        where GroqApiKeyService.isModelNotFoundError(statusCode: code, detail: detail):
                        lastModelError = error
                        continue modelLoop
                    case .apiError(let code, let detail)
                        where GroqApiKeyService.isAuthError(statusCode: code, detail: detail):
                        lastAuthError = error
                        continue
                    default:
                        throw error
                    }
                }
            }
        }

        if case .apiError(let code, _) = lastAuthError {
            throw GroqLotError.apiError(code, GroqApiKeyService.authFailureMessage(statusCode: code))
        }
        if let lastModelError {
            throw lastModelError
        }
        throw GroqLotError.missingApiKey
    }

    private func resolvedModelCandidates(preferred: String, apiKey: String) async -> [String] {
        let available = await GroqVisionModelResolver.visionModels(apiKey: apiKey)
        var chain: [String] = []
        if !preferred.isEmpty { chain.append(preferred) }
        for model in available where !chain.contains(model) {
            chain.append(model)
        }
        for model in Self.visionModelChain where !chain.contains(model) {
            chain.append(model)
        }
        return chain
    }

    private func orderedKeysForRequest() -> [String] {
        var keys: [String] = []
        if !apiKey.isEmpty { keys.append(apiKey) }
        if let fallbackApiKey, !fallbackApiKey.isEmpty, fallbackApiKey != apiKey {
            keys.append(fallbackApiKey)
        }
        return keys
    }

    private func performChatCompletion(
        apiKey: String,
        jpegVariants: [Data],
        system: String,
        prompt: String,
        model: String
    ) async throws -> String {
        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        for jpeg in jpegVariants {
            content.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": content]
            ],
            "temperature": 0,
            "max_tokens": 160,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 22

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GroqLotError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GroqLotError.apiError(http.statusCode, detail)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw GroqLotError.emptyContent
        }
        return text
    }
}

enum GroqLotError: LocalizedError {
    case missingApiKey
    case invalidResponse
    case emptyContent
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Configura la chiave Groq in Impostazioni → HACCP oppure aggiungi GroqSecrets.plist al progetto (chiave organizzazione)."
        case .invalidResponse:
            return "Risposta Groq non valida."
        case .emptyContent:
            return "Groq non ha restituito contenuto."
        case .apiError(let code, let detail):
            if GroqApiKeyService.isAuthError(statusCode: code, detail: detail) {
                return GroqApiKeyService.authFailureMessage(statusCode: code)
            }
            if GroqApiKeyService.isModelNotFoundError(statusCode: code, detail: detail) {
                return "Modello OCR Groq non disponibile sulla chiave configurata. Verifica la chiave su console.groq.com o inserisci il lotto manualmente."
            }
            return "Errore Groq (\(code)): \(detail.prefix(200))"
        }
    }
}
