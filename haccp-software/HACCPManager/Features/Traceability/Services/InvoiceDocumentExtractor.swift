import Foundation
import UIKit
import Vision

/// Estrae solo Codice / Lotto / Descrizione dalla tabella prodotti di fattura/DDT.
struct InvoiceDocumentExtractor: Sendable {
    private static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private static let model = "meta-llama/llama-4-scout-17b-16e-instruct"
    private static let fallbackModel = "qwen/qwen3.6-27b"
    private static let maxDocumentPixel: CGFloat = 2560

    enum ExtractError: LocalizedError {
        case noProductRows

        var errorDescription: String? {
            "Non ho trovato la tabella prodotti (Codice, Lotto, Descrizione). Inquadra meglio la griglia al centro del documento e riprova."
        }
    }

    func extract(from imageData: Data) async throws -> InvoiceDocumentExtraction {
        guard !imageData.isEmpty else {
            throw GroqLotError.invalidResponse
        }

        // 1) Primario: Vision a colonne (bounding box) — massima precisione su tabelle stampate
        let visionFull = await Task.detached(priority: .userInitiated) {
            InvoiceTableColumnParser.extract(from: imageData)
        }.value
        let visionBand: InvoiceDocumentExtraction? = await Task.detached(priority: .userInitiated) {
            guard let band = Self.tableBandJPEG(from: imageData) else { return nil }
            return InvoiceTableColumnParser.extract(from: band)
        }.value

        var visionBest: InvoiceDocumentExtraction?
        if let visionFull { visionBest = Self.sanitized(visionFull, source: "Vision colonne full") }
        if let visionBand {
            let cleaned = Self.sanitized(visionBand, source: "Vision colonne fascia")
            visionBest = Self.pickBetter(visionBest, cleaned)
        }
        if let visionBest, Self.isHighPrecision(visionBest) {
            return visionBest
        }

        let jpegFull = await Task.detached(priority: .userInitiated) {
            ImageProcessor.preparedJPEGData(
                from: imageData,
                maxPixel: Self.maxDocumentPixel,
                quality: 0.92
            ) ?? imageData
        }.value

        let jpegTable = await Task.detached(priority: .userInitiated) {
            Self.tableBandJPEG(from: imageData) ?? jpegFull
        }.value

        var best = visionBest
        var lastError: Error?

        if GroqApiKeyService.hasAnyKey() {
            // 2) Groq sul ritaglio tabella — solo se Vision non ha chiuso tutte le righe
            do {
                let raw = try await chatCompletion(
                    jpeg: jpegTable,
                    system: Self.systemPrompt,
                    prompt: Self.tableOnlyPrompt
                )
                let parsed = Self.sanitized(Self.parse(jsonText: raw), source: "Groq fascia tabella")
                best = Self.pickBetter(best, parsed)
                if let best, Self.isHighPrecision(best) {
                    return best
                }
            } catch {
                lastError = error
            }

            do {
                let raw = try await chatCompletion(
                    jpeg: jpegFull,
                    system: Self.systemPrompt,
                    prompt: Self.userPrompt
                )
                let parsed = Self.sanitized(Self.parse(jsonText: raw), source: "Groq documento intero")
                best = Self.pickBetter(best, parsed)
                if let best, Self.isHighPrecision(best) {
                    return best
                }
            } catch {
                lastError = error
            }
        }

        // 3) Fallback OCR lineare legacy
        if let local = await extractWithVisionTableParser(imageData: imageData) {
            best = Self.pickBetter(best, Self.sanitized(local, source: "Vision lineare"))
        }

        if let best, Self.hasUsableProductRows(best) {
            return best
        }

        if let lastError, best == nil || best?.rows.isEmpty == true {
            if case GroqLotError.missingApiKey = lastError { throw lastError }
            if case GroqLotError.apiError = lastError { throw lastError }
        }
        throw ExtractError.noProductRows
    }

    // MARK: - Quality

    /// Almeno 8 righe con codice+lotto+descrizione ben formati (DDT tipico ~10–15).
    static func isHighPrecision(_ extraction: InvoiceDocumentExtraction) -> Bool {
        let rows = extraction.rows.filter(isStrictProductRow)
        return rows.count >= 8
    }

    static func hasUsableProductRows(_ extraction: InvoiceDocumentExtraction) -> Bool {
        extraction.rows.filter(isStrictProductRow).count >= 1
    }

    static func isStrictProductRow(_ row: InvoiceLineItem) -> Bool {
        InvoiceLineNormalizer.looksLikeArticleCode(row.productCode)
            && InvoiceLineNormalizer.looksLikeProductDescription(row.description)
            && (row.lotCode == nil || InvoiceLineNormalizer.looksLikeLot(row.lotCode))
    }

    static func pickBetter(
        _ a: InvoiceDocumentExtraction?,
        _ b: InvoiceDocumentExtraction
    ) -> InvoiceDocumentExtraction {
        guard let a else { return b }
        let scoreA = a.rows.filter(isStrictProductRow).count
        let scoreB = b.rows.filter(isStrictProductRow).count
        if scoreB != scoreA { return scoreB > scoreA ? b : a }
        return b.confidence >= a.confidence ? b : a
    }

    static func sanitized(_ extraction: InvoiceDocumentExtraction, source: String) -> InvoiceDocumentExtraction {
        var copy = extraction
        copy.rows = InvoiceLineNormalizer.normalizeAll(extraction.rows)
        copy.confidence = copy.rows.isEmpty ? min(extraction.confidence, 0.3) : max(extraction.confidence, 0.9)
        copy.auditLines = [source, "\(copy.rows.count) righe normalizzate"] + extraction.auditLines
        if let supplier = copy.supplierName, looksLikeJunkSupplier(supplier) {
            copy.supplierName = nil
        }
        // Forza kind DDT se riconosciamo tabella prodotti
        if copy.documentKind == .unknown, copy.rows.count >= 3 {
            copy.documentKind = .ddt
        }
        return copy
    }

    static func looksLikeJunkSupplier(_ text: String) -> Bool {
        let u = text.uppercased()
        return u.contains("@") || u.contains("HTTP") || u.contains("VIA ")
    }

    // MARK: - Image prep

    /// Ritaglio ~55% centrale (dove di solito sta la tabella prodotti).
    private static func tableBandJPEG(from imageData: Data) -> Data? {
        guard let image = ImageProcessor.downsampledImage(from: imageData, maxPixel: maxDocumentPixel),
              let cg = image.cgImage else { return nil }
        let w = cg.width
        let h = cg.height
        guard w > 40, h > 80 else { return nil }
        let y = Int(Double(h) * 0.22)
        let bandH = Int(Double(h) * 0.58)
        let rect = CGRect(x: 0, y: y, width: w, height: min(bandH, h - y))
        guard let cropped = cg.cropping(to: rect) else { return nil }
        let ui = UIImage(cgImage: cropped)
        return ImageProcessor.preparedJPEGData(from: ui, maxPixel: maxDocumentPixel, quality: 0.92)
    }

    // MARK: - Groq HTTP

    private func chatCompletion(jpeg: Data, system: String, prompt: String) async throws -> String {
        let keys = GroqApiKeyService.resolvedKeys()
        var ordered: [String] = []
        if !keys.primary.isEmpty { ordered.append(keys.primary) }
        if let fb = keys.fallback, !fb.isEmpty, fb != keys.primary { ordered.append(fb) }
        guard !ordered.isEmpty else { throw GroqLotError.missingApiKey }

        let models = await resolvedModels(apiKey: ordered[0])
        var lastAuth: GroqLotError?
        var lastModel: GroqLotError?

        modelLoop: for model in models {
            for key in ordered {
                do {
                    return try await performChat(apiKey: key, jpeg: jpeg, model: model, system: system, prompt: prompt)
                } catch let error as GroqLotError {
                    switch error {
                    case .apiError(let code, let detail)
                        where GroqApiKeyService.isModelNotFoundError(statusCode: code, detail: detail):
                        lastModel = error
                        continue modelLoop
                    case .apiError(let code, let detail)
                        where GroqApiKeyService.isAuthError(statusCode: code, detail: detail):
                        lastAuth = error
                        continue
                    default:
                        throw error
                    }
                }
            }
        }

        if case .apiError(let code, _) = lastAuth {
            throw GroqLotError.apiError(code, GroqApiKeyService.authFailureMessage(statusCode: code))
        }
        if let lastModel { throw lastModel }
        throw GroqLotError.missingApiKey
    }

    private func resolvedModels(apiKey: String) async -> [String] {
        let available = await GroqVisionModelResolver.visionModels(apiKey: apiKey)
        var chain: [String] = [Self.model, Self.fallbackModel]
        for model in available where !chain.contains(model) {
            chain.append(model)
        }
        return chain
    }

    private func performChat(
        apiKey: String,
        jpeg: Data,
        model: String,
        system: String,
        prompt: String
    ) async throws -> String {
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            [
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]
            ]
        ]
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": content]
            ],
            "temperature": 0,
            "max_tokens": 4096,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 55

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GroqLotError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GroqLotError.apiError(http.statusCode, detail)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw GroqLotError.emptyContent
        }
        return text
    }

    // MARK: - Prompts

    private static let systemPrompt = """
    Sei un assistente specializzato nell'estrazione di dati da DDT e fatture alimentari italiane.

    Obiettivo: leggere SOLO la TABELLA PRODOTTI con colonne nell'ordine:
    Codice | Lotto | Descrizione

    Per ogni riga merce:
    - "codice" = SOLO il codice articolo (un token, es. DATTGIALLO, MELANZANE001, TIM). MAI una descrizione.
    - "lotto" = SOLO il numero lotto (cifre, es. 1902859).
    - "descrizione" = SOLO la descrizione prodotto (es. "DATTERINO GIALLO italia 2^"). MAI un codice articolo.

    VIETATO:
    - scambiare codice e descrizione
    - mettere la parola "Descrizione"/"Codice"/"Lotto" come valore
    - unire due righe diverse
    - estrarre indirizzi, email, IBAN, totali, U.M., quantità, prezzi

    Esempio CORRETTO:
    {"codice":"POMODORI001","lotto":"36594","descrizione":"POMODORI CILIEGINO italia 2^"}

    Esempio SBAGLIATO (non fare mai):
    {"codice":"POMODORI CILIEGINO italia 2^","lotto":"36594","descrizione":"POMODORI001"}

    Output SOLO JSON:
    {
      "document_kind": "ddt" | "fattura" | "unknown",
      "supplier_name": string|null,
      "rows": [
        {"codice": string, "lotto": string, "descrizione": string}
      ]
    }
    """

    private static let userPrompt = """
    Estrai TUTTE le righe della tabella Codice|Lotto|Descrizione in ordine.
    Non scambiare i campi. Ignora header/footer/totali.
    Output ONLY JSON.
    """

    private static let tableOnlyPrompt = """
    Ritaglio tabella. Estrai TUTTE le righe.
    codice = token articolo senza spazi; lotto = solo cifre; descrizione = testo prodotto.
    Non scambiare codice e descrizione. Non unire righe.
    Output ONLY JSON.
    """

    // MARK: - Parse

    static func parse(jsonText: String) -> InvoiceDocumentExtraction {
        let cleaned = stripMarkdownFences(jsonText)

        if let fromJSON = parseJSONObject(cleaned) {
            return fromJSON
        }
        if let fromChecklist = parseChecklistMarkdown(cleaned) {
            return fromChecklist
        }

        return InvoiceDocumentExtraction(
            documentKind: .unknown,
            documentNumber: nil,
            documentDate: nil,
            supplierName: nil,
            recipientName: nil,
            rows: [],
            confidence: 0,
            rawText: jsonText,
            auditLines: ["JSON non valido"]
        )
    }

    private static func parseJSONObject(_ cleaned: String) -> InvoiceDocumentExtraction? {
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let kindRaw = (obj["document_kind"] as? String)?.lowercased() ?? "unknown"
        let kind = InvoiceDocumentKind(rawValue: kindRaw) ?? .unknown
        let rowsJSON = obj["rows"] as? [[String: Any]] ?? []
        let rows = rowsJSON.compactMap(parseRow)

        return InvoiceDocumentExtraction(
            documentKind: kind,
            documentNumber: stringValue(obj["document_number"]),
            documentDate: nil,
            supplierName: stringValue(obj["supplier_name"]),
            recipientName: stringValue(obj["recipient_name"]),
            rows: rows,
            confidence: rows.isEmpty ? 0.3 : 0.9,
            rawText: cleaned,
            auditLines: ["\(rows.count) righe grezze"]
        )
    }

    private static func parseRow(_ row: [String: Any]) -> InvoiceLineItem? {
        let description = preserveExact(
            stringValue(row["descrizione"]) ?? stringValue(row["description"])
        ) ?? ""
        let code = preserveExact(
            stringValue(row["codice"])
                ?? stringValue(row["code"])
                ?? stringValue(row["productCode"])
        )
        let lot = preserveExact(
            stringValue(row["lotto"])
                ?? stringValue(row["lot"])
                ?? stringValue(row["lotCode"])
        )
        guard !description.isEmpty else { return nil }
        return InvoiceLineItem(
            productCode: code,
            lotCode: lot,
            description: description
        )
    }

    private static func parseChecklistMarkdown(_ text: String) -> InvoiceDocumentExtraction? {
        let pattern = #"- \[ \] Codice:\s*(.*?)\s*\|\s*Lotto:\s*(.*?)\s*\|\s*Descrizione:\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return nil
        }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }

        let rows: [InvoiceLineItem] = matches.compactMap { match in
            guard match.numberOfRanges >= 4,
                  let codeR = Range(match.range(at: 1), in: text),
                  let lotR = Range(match.range(at: 2), in: text),
                  let descR = Range(match.range(at: 3), in: text) else { return nil }
            let code = String(text[codeR]).trimmingCharacters(in: .whitespacesAndNewlines)
            let lot = String(text[lotR]).trimmingCharacters(in: .whitespacesAndNewlines)
            let desc = String(text[descR]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !desc.isEmpty else { return nil }
            return InvoiceLineItem(
                productCode: code.isEmpty || code == "—" ? nil : code,
                lotCode: lot.isEmpty || lot == "—" ? nil : lot,
                description: desc
            )
        }
        guard !rows.isEmpty else { return nil }

        return InvoiceDocumentExtraction(
            documentKind: .unknown,
            documentNumber: nil,
            documentDate: nil,
            supplierName: nil,
            recipientName: nil,
            rows: rows,
            confidence: 0.8,
            rawText: text,
            auditLines: ["Checklist Markdown"]
        )
    }

    private static func preserveExact(_ value: String?) -> String? {
        guard let value else { return nil }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.lowercased() == "null" || t == "—" || t == "-" { return nil }
        return t
    }

    private static func stripMarkdownFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
            t = t.replacingOccurrences(of: "```", with: "")
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    private static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t.lowercased() == "null" { return nil }
            return t
        }
        if let n = any as? NSNumber {
            return n.stringValue
        }
        return nil
    }

    // MARK: - Vision table parser

    private func extractWithVisionTableParser(imageData: Data) async -> InvoiceDocumentExtraction? {
        let text = await Task.detached(priority: .userInitiated) {
            Self.recognizeTextBlocking(in: imageData)
        }.value
        guard !text.isEmpty else { return nil }

        let upper = text.uppercased()
        let kind: InvoiceDocumentKind
        if upper.contains("DOCUMENTO DI TRASPORTO") || upper.contains("DDT") {
            kind = .ddt
        } else if upper.contains("FATTURA") {
            kind = .fattura
        } else {
            kind = .unknown
        }

        let rows = Self.parseTableRowsFromOCR(text)
        guard !rows.isEmpty else { return nil }

        let supplier = Self.firstMatch(
            in: text,
            patterns: [
                #"((?:Fruitchef|FRUITCHEF)[^\n]{0,40})"#,
                #"Mittente[:\s]+([A-Za-z0-9 .,&'\-]{3,60})"#
            ]
        )

        return Self.sanitized(
            InvoiceDocumentExtraction(
                documentKind: kind,
                documentNumber: Self.firstMatch(in: text, patterns: [#"Numero\s*doc\.?[:\s]*([0-9./]+)"#]),
                documentDate: nil,
                supplierName: supplier,
                recipientName: nil,
                rows: rows,
                confidence: 0.7,
                rawText: text,
                auditLines: ["Apple Vision tabella"]
            ),
            source: "Apple Vision tabella"
        )
    }

    /// Parsing strutturato: `CODICE LOTTO DESCRIZIONE…` sulla stessa riga OCR.
    static func parseTableRowsFromOCR(_ text: String) -> [InvoiceLineItem] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var rows: [InvoiceLineItem] = []
        let inline = try? NSRegularExpression(
            pattern: #"^([A-Za-z][A-Za-z0-9._\-/]{1,28})\s+(\d{4,10})\s+(.+)$"#
        )

        for line in lines {
            if InvoiceLineNormalizer.isHeaderToken(line) { continue }
            let u = line.uppercased()
            if u.contains("TOTALE") || u.contains("BANCA") || line.contains("@") { continue }
            guard let inline else { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard let match = inline.firstMatch(in: line, range: range),
                  match.numberOfRanges >= 4,
                  let cR = Range(match.range(at: 1), in: line),
                  let lR = Range(match.range(at: 2), in: line),
                  let dR = Range(match.range(at: 3), in: line) else { continue }

            let code = String(line[cR])
            let lot = String(line[lR])
            var desc = String(line[dR])
            if let um = desc.range(
                of: #"\s+(KG|PZ|CL|GR|G|LT|L)\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) {
                desc = String(desc[..<um.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            rows.append(InvoiceLineItem(productCode: code, lotCode: lot, description: desc))
        }

        if rows.count < 2 {
            rows = parseTripletRows(lines)
        }

        return InvoiceLineNormalizer.normalizeAll(rows)
    }

    private static func parseTripletRows(_ lines: [String]) -> [InvoiceLineItem] {
        var rows: [InvoiceLineItem] = []
        var i = 0
        while i < lines.count {
            let a = lines[i]
            if InvoiceLineNormalizer.looksLikeArticleCode(a),
               i + 2 < lines.count,
               InvoiceLineNormalizer.looksLikeLot(lines[i + 1]),
               InvoiceLineNormalizer.looksLikeProductDescription(lines[i + 2]) {
                rows.append(
                    InvoiceLineItem(
                        productCode: a,
                        lotCode: lines[i + 1],
                        description: lines[i + 2]
                    )
                )
                i += 3
                continue
            }
            i += 1
        }
        return rows
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                if match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text) {
                    let value = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !looksLikeJunkSupplier(value) { return value }
                }
            }
        }
        return nil
    }

    private static func recognizeTextBlocking(in imageData: Data) -> String {
        guard let image = ImageProcessor.downsampledImage(
            from: imageData,
            maxPixel: maxDocumentPixel
        ),
        let cgImage = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["it-IT", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }
        let observations = (request.results ?? [])
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

// MARK: - Template matching

enum InvoiceProductTemplateMatcher {
    static func bestMatch(for description: String, in templates: [ProductTemplate]) -> ProductTemplate? {
        let needle = normalize(description)
        guard !needle.isEmpty else { return nil }

        var best: (ProductTemplate, Int)?
        for template in templates {
            let name = normalize(template.name)
            guard !name.isEmpty else { continue }
            var score = 0
            if name == needle { score = 100 }
            else if needle.contains(name) || name.contains(needle) { score = 80 }
            else {
                let needleTokens = Set(needle.split(separator: " ").map(String.init).filter { $0.count > 2 })
                let nameTokens = Set(name.split(separator: " ").map(String.init).filter { $0.count > 2 })
                let overlap = needleTokens.intersection(nameTokens).count
                if overlap > 0 {
                    score = 40 + overlap * 15
                }
            }
            if score > 0, best == nil || score > best!.1 {
                best = (template, score)
            }
        }
        guard let best, best.1 >= 40 else { return nil }
        return best.0
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .lowercased()
            .replacingOccurrences(of: #"italia\s*\d\^?"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\b(kg|pz|cl|gr|g|lt|l)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
