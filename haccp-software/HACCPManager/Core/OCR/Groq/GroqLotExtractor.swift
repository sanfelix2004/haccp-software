import Foundation

/// Lettura etichetta via Groq Vision — ritaglio area stampa + multi-immagine + validazione locale.
struct GroqLotExtractor: LabelLotExtractorProtocol, Sendable {
    let apiKey: String

    private static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private static let model = "meta-llama/llama-4-maverick-17b-128e-instruct"
    private static let fallbackModel = "meta-llama/llama-4-scout-17b-16e-instruct"

    /// Sotto questa soglia l'operatore deve verificare manualmente.
    static let manualVerificationThreshold = 0.85

    init(apiKey: String) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func analyzeLabel(from imageData: Data, expectedIngredients: [String]) async throws -> LabelLotExtractionResult {
        guard !apiKey.isEmpty else { throw GroqLotError.missingApiKey }

        let images = GroqVisionImagePreprocessor.prepare(from: imageData)
            ?? fallbackSingleImage(from: imageData)

        var audit = [
            "Groq \(Self.model)",
            "Varianti immagine: ritaglio stampa + invertito + panorama",
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

        if GroqLabelValidator.shouldRetryLot(issues) {
            audit.append("Retry lotto su immagine invertita (sfondo scuro)")
            let lotPass = try await chatCompletion(
                jpegVariants: [images.stampInvertedJPEG],
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
            audit.append("Retry scadenza (ignora orario HH:MM)")
            let expiryPass = try await chatCompletion(
                jpegVariants: [images.stampFocusJPEG, images.stampInvertedJPEG],
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

        if !issues.isEmpty, parsed.lot != nil || parsed.expiry != nil {
            audit.append("Verifica finale su tutte le varianti")
            let verifyRaw = try await chatCompletion(
                jpegVariants: [
                    images.stampFocusJPEG,
                    images.stampInvertedJPEG,
                    images.fullFrameJPEG
                ],
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

        return LabelLotExtractionResult(
            rawText: parsed.rawPayload,
            extractedIngredient: nil,
            extractedLotCode: parsed.lot,
            extractedExpiryDate: parsed.expiry,
            confidence: confidence,
            auditLines: audit
        )
    }

    // MARK: - Passes

    private func runPrimaryPass(
        images: GroqVisionImagePreprocessor.PreparedImages,
        expectedIngredients: [String],
        audit: inout [String]
    ) async throws -> GroqLabelResponseParser.Parsed {
        let variants = [images.stampFocusJPEG, images.fullFrameJPEG]
        do {
            let raw = try await chatCompletion(
                jpegVariants: variants,
                system: Self.systemPrompt,
                prompt: Self.primaryPrompt(expectedIngredients: expectedIngredients)
            )
            return GroqLabelResponseParser.parse(raw)
        } catch {
            audit.append("Fallback modello Scout")
            let raw = try await chatCompletion(
                jpegVariants: variants,
                system: Self.systemPrompt,
                prompt: Self.primaryPrompt(expectedIngredients: expectedIngredients),
                model: Self.fallbackModel
            )
            return GroqLabelResponseParser.parse(raw)
        }
    }

    private func fallbackSingleImage(from data: Data) -> GroqVisionImagePreprocessor.PreparedImages {
        let jpeg = ImageProcessor.preparedJPEGData(
            from: data,
            maxPixel: PerformanceConfig.groqVisionMaxPixel,
            quality: PerformanceConfig.groqVisionJPEGQuality
        ) ?? data
        return GroqVisionImagePreprocessor.PreparedImages(
            stampFocusJPEG: jpeg,
            stampInvertedJPEG: jpeg,
            fullFrameJPEG: jpeg
        )
    }

    // MARK: - Prompts

    private static let systemPrompt = """
    Sei un OCR per etichette alimentari HACCP (Italia/UE).
    Ricevi una o più foto della stessa etichetta. La prima è spesso un INGRANDIMENTO dell'area stampa lotto/data.
    Leggi SOLO testo stampato. Non inventare.

    SCADENZA: TMC, SCAD, "Da consumarsi preferibilmente entro", EXP, Best Before.
    Formati GG/MM/AAAA, GG.MM.AA, DDMMYY, mesi AGO/AUG/OTT/DIC.
    CRITICO: "23/08/2026 06:08" → scadenza 23/08/2026 — IGNORA l'orario HH:MM.

    LOTTO: L6036BH099, L52400V757 — se la L è stampata attaccata al codice, mantienila.
    Rimuovi solo etichette testuali (Lotto:, Lot:, Batch:), non la L iniziale del codice.
    """

    private static func primaryPrompt(expectedIngredients: [String]) -> String {
        var lines = [
            "Immagine 1 = zoom area stampa. Immagine 2 = inquadratura completa.",
            "Estrai scadenza e lotto. JSON: {\"scadenza\":\"GG/MM/AAAA\",\"lotto\":\"\"}",
            "scadenza = solo data calendario. lotto = codice esatto come stampato (es. L6036BH099).",
            "Se illeggibile usa \"\"."
        ]
        if let first = expectedIngredients.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !first.isEmpty {
            lines.insert("Prodotto: \(first.prefix(48)).", at: 1)
        }
        return lines.joined(separator: "\n")
    }

    private static let lotOnlyPrompt = """
    Solo LOTTO dalla stampa a matrice. Esempi: L6036BH099, L52400V757 — includi la L se c'è.
    Non confondere V con Y. JSON: {"lotto":""}
    """

    private static let expiryOnlyPrompt = """
    Solo DATA SCADENZA. Ignora orario produzione (06:08 non è una data).
    Se vedi "23/08/2026 06:08" → "23/08/2026".
    JSON: {"scadenza":"GG/MM/AAAA"}
    """

    private static func verifyPrompt(lot: String?, expiry: Date?) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        df.dateFormat = "dd/MM/yyyy"
        let lotText = lot ?? "?"
        let expiryText = expiry.map { df.string(from: $0) } ?? "?"
        return """
        Controlla lotto e scadenza nell'immagine (usa lo zoom):
        - lotto proposto: \(lotText)
        - scadenza proposta: \(expiryText)
        Correggi errori (V/Y, data vs orario). JSON: {"scadenza":"GG/MM/AAAA","lotto":""}
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
            "max_tokens": 80,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

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
            return "Configura la chiave API Groq in Impostazioni → HACCP."
        case .invalidResponse:
            return "Risposta Groq non valida."
        case .emptyContent:
            return "Groq non ha restituito contenuto."
        case .apiError(let code, let detail):
            return "Errore Groq (\(code)): \(detail.prefix(200))"
        }
    }
}
