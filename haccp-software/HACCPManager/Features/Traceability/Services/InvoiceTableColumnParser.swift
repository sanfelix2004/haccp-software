import Foundation
import UIKit
import Vision

/// Ricostruisce la tabella prodotti usando le bounding box OCR (colonne X).
enum InvoiceTableColumnParser {
    struct OCRToken {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let minX: CGFloat
        let maxX: CGFloat
    }

    static func extract(from imageData: Data, maxPixel: CGFloat = 2800) -> InvoiceDocumentExtraction? {
        guard let image = ImageProcessor.downsampledImage(from: imageData, maxPixel: maxPixel),
              let cgImage = image.cgImage else { return nil }

        let tokens = recognizeTokens(cgImage: cgImage)
        guard tokens.count >= 6 else { return nil }

        let kind = detectKind(from: tokens.map(\.text))
        let columns = resolveColumns(tokens: tokens)
        let rows = buildRows(tokens: tokens, columns: columns)
        let normalized = InvoiceLineNormalizer.normalizeAll(rows)

        guard !normalized.isEmpty else { return nil }

        let supplier = tokens.map(\.text).first {
            $0.localizedCaseInsensitiveContains("Fruitchef")
        }

        return InvoiceDocumentExtraction(
            documentKind: kind,
            documentNumber: nil,
            documentDate: nil,
            supplierName: supplier,
            recipientName: nil,
            rows: normalized,
            confidence: normalized.count >= 8 ? 0.98 : (normalized.count >= 5 ? 0.94 : 0.85),
            rawText: tokens.map(\.text).joined(separator: "\n"),
            auditLines: [
                "Vision colonne X",
                "codice@\(String(format: "%.2f", columns.codiceX))",
                "lotto@\(String(format: "%.2f", columns.lottoX))",
                "desc@\(String(format: "%.2f", columns.descX))",
                "\(normalized.count) righe"
            ]
        )
    }

    // MARK: OCR

    private static func recognizeTokens(cgImage: CGImage) -> [OCRToken] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["it-IT", "en-US"]
        if #available(iOS 16.0, *) {
            request.minimumTextHeight = 0.008
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        var tokens: [OCRToken] = []
        for obs in request.results ?? [] {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let box = obs.boundingBox
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            tokens.append(contentsOf: splitObservationText(text, box: box))
        }
        return tokens
    }

    private static func splitObservationText(_ text: String, box: CGRect) -> [OCRToken] {
        let midY = 1 - (box.origin.y + box.height / 2)
        let minX = box.minX
        let maxX = box.maxX
        let width = max(box.width, 0.001)

        if let regex = try? NSRegularExpression(
            pattern: #"^([A-Za-z][A-Za-z0-9._\-/]{1,28})\s+(\d{4,10})\s+(.+)$"#
        ) {
            let range = NSRange(text.startIndex..., in: text)
            if let m = regex.firstMatch(in: text, range: range),
               m.numberOfRanges >= 4,
               let cR = Range(m.range(at: 1), in: text),
               let lR = Range(m.range(at: 2), in: text),
               let dR = Range(m.range(at: 3), in: text) {
                let c = String(text[cR])
                let l = String(text[lR])
                let d = trimTrailingQty(String(text[dR]))
                return [
                    OCRToken(text: c, x: minX + width * 0.08, y: midY, minX: minX, maxX: minX + width * 0.2),
                    OCRToken(text: l, x: minX + width * 0.28, y: midY, minX: minX + width * 0.2, maxX: minX + width * 0.4),
                    OCRToken(text: d, x: minX + width * 0.65, y: midY, minX: minX + width * 0.4, maxX: maxX)
                ]
            }
        }

        return [OCRToken(text: text, x: box.midX, y: midY, minX: minX, maxX: maxX)]
    }

    private static func trimTrailingQty(_ text: String) -> String {
        var d = text
        if let r = d.range(
            of: #"\s+(KG|PZ|CL|GR|G|LT|L)\b.*"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            d = String(d[..<r.lowerBound])
        }
        d = d.replacingOccurrences(of: #"\s+\d+[.,]\d+\s*$"#, with: "", options: .regularExpression)
        return d.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Columns

    private struct Columns {
        var codiceX: CGFloat
        var lottoX: CGFloat
        var descX: CGFloat
        var codiceMax: CGFloat
        var lottoMax: CGFloat
    }

    private static func resolveColumns(tokens: [OCRToken]) -> Columns {
        let headers = tokens.filter {
            let u = $0.text.uppercased()
            return u == "CODICE" || u == "LOTTO" || u.hasPrefix("DESCRIZ")
        }

        if let c = headers.first(where: { $0.text.uppercased() == "CODICE" }),
           let l = headers.first(where: { $0.text.uppercased() == "LOTTO" }),
           let d = headers.first(where: { $0.text.uppercased().hasPrefix("DESCRIZ") }) {
            return Columns(
                codiceX: c.x,
                lottoX: l.x,
                descX: d.x,
                codiceMax: (c.x + l.x) / 2,
                lottoMax: (l.x + d.x) / 2
            )
        }

        let codeLike = tokens.filter { InvoiceLineNormalizer.looksLikeArticleCode($0.text) && $0.x < 0.35 }
        let lotLike = tokens.filter { InvoiceLineNormalizer.looksLikeLot($0.text) && $0.x < 0.45 }
        let codiceX = median(codeLike.map(\.x)) ?? 0.08
        let lottoX = median(lotLike.map(\.x)) ?? 0.18
        return Columns(
            codiceX: codiceX,
            lottoX: max(lottoX, codiceX + 0.05),
            descX: 0.42,
            codiceMax: (codiceX + max(lottoX, codiceX + 0.05)) / 2,
            lottoMax: 0.32
        )
    }

    private static func median(_ values: [CGFloat]) -> CGFloat? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        return s[s.count / 2]
    }

    // MARK: Rows

    private static func buildRows(tokens: [OCRToken], columns: Columns) -> [InvoiceLineItem] {
        let filtered = tokens.filter { token in
            let u = token.text.uppercased()
            if InvoiceLineNormalizer.isHeaderToken(u) { return false }
            if u.contains("DOCUMENTO DI TRASPORTO") { return false }
            if u.contains("TOTALE") || u.contains("IMPONIBILE") { return false }
            if u.contains("BANCA") || u.contains("IBAN") || token.text.contains("@") { return false }
            return token.y > 0.10 && token.y < 0.85
        }

        let sorted = filtered.sorted { $0.y < $1.y }
        var clusters: [[OCRToken]] = []
        let yThreshold: CGFloat = 0.013

        for token in sorted {
            if var last = clusters.last, let ref = last.first, abs(ref.y - token.y) <= yThreshold {
                last.append(token)
                clusters[clusters.count - 1] = last
            } else {
                clusters.append([token])
            }
        }

        return clusters.compactMap { rowFromCluster($0, columns: columns) }
    }

    private static func rowFromCluster(_ cluster: [OCRToken], columns: Columns) -> InvoiceLineItem? {
        var codeParts: [String] = []
        var lotParts: [String] = []
        var descParts: [String] = []

        for token in cluster.sorted(by: { $0.x < $1.x }) {
            let t = token.text
            if token.x < columns.codiceMax {
                if InvoiceLineNormalizer.looksLikeLot(t) {
                    lotParts.append(t)
                } else {
                    codeParts.append(t)
                }
            } else if token.x < columns.lottoMax {
                if InvoiceLineNormalizer.looksLikeLot(t) {
                    lotParts.append(t)
                } else if InvoiceLineNormalizer.looksLikeArticleCode(t), codeParts.isEmpty {
                    codeParts.append(t)
                } else {
                    descParts.append(t)
                }
            } else {
                let u = t.uppercased()
                if ["KG", "PZ", "CL", "GR", "LT", "L"].contains(u) { continue }
                if t.range(of: #"^\d+[.,]\d+$"#, options: .regularExpression) != nil { continue }
                if t.range(of: #"^\d+$"#, options: .regularExpression) != nil, t.count <= 3 { continue }
                descParts.append(t)
            }
        }

        if codeParts.isEmpty {
            codeParts = cluster.compactMap {
                InvoiceLineNormalizer.looksLikeArticleCode($0.text) ? $0.text : nil
            }
        }
        if lotParts.isEmpty {
            lotParts = cluster.compactMap {
                InvoiceLineNormalizer.looksLikeLot($0.text) ? $0.text : nil
            }
        }
        if descParts.isEmpty {
            descParts = cluster
                .sorted { $0.x < $1.x }
                .map(\.text)
                .filter {
                    !InvoiceLineNormalizer.looksLikeArticleCode($0)
                        && !InvoiceLineNormalizer.looksLikeLot($0)
                        && !InvoiceLineNormalizer.isHeaderToken($0)
                }
        }

        let code = codeParts.first { InvoiceLineNormalizer.looksLikeArticleCode($0) } ?? codeParts.first
        let lot = lotParts.first { InvoiceLineNormalizer.looksLikeLot($0) }
        let desc = trimTrailingQty(descParts.joined(separator: " "))
        guard !desc.isEmpty else { return nil }
        return InvoiceLineItem(productCode: code, lotCode: lot, description: desc)
    }

    private static func detectKind(from texts: [String]) -> InvoiceDocumentKind {
        let joined = texts.joined(separator: " ").uppercased()
        if joined.contains("DOCUMENTO DI TRASPORTO") || joined.contains(" DDT") {
            return .ddt
        }
        if joined.contains("FATTURA") {
            return .fattura
        }
        return .unknown
    }
}
