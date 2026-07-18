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
            "Varianti: focus alto + basso + frame intero",
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
        // Tre viste: focus alto, stampigliatura basso, panorama — come da system prompt.
        let variants = limitedVariants([
            images.stampFocusJPEG,
            images.stampBottomJPEG,
            images.fullFrameJPEG
        ], maxCount: 3)
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
      "lotto": "stringa alfanumerica industriale o null",
      "scadenza": "YYYY-MM-DD o null"
    }
    """

    private static let systemPrompt = """
    SEI UN OCR INDUSTRIALE DI LIVELLO AUTOMOTIVE, PROGRAMMATO PER LA TRACCIABILITA ALIMENTARE HACCP.
    TI VENGONO FORNITE MULTIPLE VARIANTI DELLA STESSA FOTO (RITAGLI FOCUS + FRAME INTERO). ANALIZZALE TUTTE PER TROVARE LA STAMPIGLIATURA A GETTO D'INCHIOSTRO.

    Image 1 = ritaglio FOCUS alto (etichetta/retro). Image 2 = ritaglio STAMPIGLIATURA basso (tappo/fondo). Image 3 = FRAME INTERO.

    REGOLA D'ORO DI ESCLUSIONE:
    IGNORA QUALSIASI SCRITTA STAMPATA SUL PACKAGING COMMERCIALE (Nomi prodotti come "LATTE", "YOGURT", "GRECO", marchi, ingredienti, tabelle nutrizionali).
    Concentrati SOLO sui caratteri puntiformi neri o laser impressi in fabbrica.

    CONVERSIONE DATE:
    - "31/08/26" -> "2026-08-31" (sempre GG/MM europeo).
    - Solo mese/anno "08/26" o "08/2026" -> ultimo giorno del mese "2026-08-31".
    - "09 10 26" -> "2026-10-09". MAI anno-first (2009/2031 inventati).
    - Ignora orari di produzione accanto alla data (es. "23/08/2026 06:08" -> "2026-08-23").

    LOTTO:
    - Stringa alfanumerica isolata di produzione (es. "08:18H-FYB", "4B22", "L9330B8", "15701", "44464").
    - Yogurt/vaschetta tipico: riga1 "31/08/26" = scadenza, riga2 "08:18H-FYB" = lotto. MAI "LATTE"/"LATTY"/"YOGURT"/"GRECO".
    - "Batch number: 44464" → lotto "44464". MAI "number"/"batch"/"Batch number".
    - "Best Before End: 11/2027" → scadenza fine mese "2027-11-30", NON e' il lotto.
    - NON usare mai "to_found", "lotto_found", "not_found", "number", nomi prodotto, EAN 12-14 cifre.

    FORMATO DI OUTPUT (RIGIDO):
    Restituisci ESCLUSIVAMENTE un oggetto JSON. Nessun testo prima/dopo. Nessun markdown. Nessun placeholder.
    Se un dato manca: null. NON inventare chiavi extra (niente lotto_found, expiration_found, ragionamento, ecc.).

    Usa TASSATIVAMENTE solo queste due chiavi:
    \(jsonOutputSchema)
    """

    private static func primaryPrompt(expectedIngredients: [String]) -> String {
        var lines = [
            "Analizza TUTTE le immagini (focus + stampigliatura basso + frame intero).",
            "Cerca SOLO stampigliatura industriale a getto/matrice/laser.",
            "Output ONLY JSON con esattamente due chiavi: lotto, scadenza."
        ]
        if let first = expectedIngredients.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !first.isEmpty {
            lines.insert("Contesto prodotto (NON e' il lotto): \(first.prefix(40)).", at: 1)
        }
        return lines.joined(separator: "\n")
    }

    private static let expiryOnlyPrompt = """
    Solo SCADENZA. lotto=null.
    ISO YYYY-MM-DD. "31/08/26" -> "2026-08-31". "08/26" -> "2026-08-31". "09 10 26" -> "2026-10-09".
    Output ONLY {"lotto":null,"scadenza":"YYYY-MM-DD"} o scadenza null.
    """

    private static let lotOnlyPrompt = """
    Solo LOTTO industriale. scadenza=null.
    Mai LATTE/YOGURT/GRECO/number/batch/to_found/lotto_found.
    "Batch number: 44464" -> lotto "44464".
    Output ONLY {"lotto":"...","scadenza":null} o lotto null.
    """

    private static func verifyPrompt(lot: String?, expiry: Date?) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB")
        df.dateFormat = "yyyy-MM-dd"
        let lotText = lot ?? "null"
        let expiryText = expiry.map { df.string(from: $0) } ?? "null"
        return """
        Verifica stampigliatura industriale (ignora packaging):
        - lotto proposto: \(lotText)
        - scadenza proposta: \(expiryText)
        Correggi se errato. Output ONLY {"lotto":...,"scadenza":...}.
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
            "max_tokens": 320,
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
