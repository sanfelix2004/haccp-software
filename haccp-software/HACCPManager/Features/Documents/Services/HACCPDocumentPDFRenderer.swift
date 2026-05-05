import UIKit

enum PDFTableCell {
    case text(String)
    case image(Data?)
}

/// Generazione PDF professionale in italiano (header, tabelle, footer).
enum HACCPDocumentPDFRenderer {
    /// A4 orizzontale: migliora leggibilità tabelle con molte colonne.
    private static let pageRect = CGRect(x: 0, y: 0, width: 842, height: 595)
    private static let margin: CGFloat = 36
    private static let footerReserve: CGFloat = 32

    /// Se `omitBuiltInFooter` è true, il footer con numerazione è applicato da `HACCPPDFOfficialFooterStamper`.
    static func render(
        restaurantName: String,
        reportTitle: String,
        periodLine: String,
        generatedAt: Date,
        sections: [(title: String, headers: [String], rows: [[PDFTableCell]])],
        omitBuiltInFooter: Bool = false,
        bodyFontSize: CGFloat = 7.2
    ) -> Data? {
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "it_IT")
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .short
        let generatedLine = dateFmt.string(from: generatedAt)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            var pageIndex = 0
            var y: CGFloat = margin
            let bottomLimit = pageRect.height - margin - footerReserve

            func drawFooterOnCurrentPage() {
                guard !omitBuiltInFooter else { return }
                let footerY = pageRect.height - margin + 2
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                    .foregroundColor: UIColor.gray
                ]
                let left = "Generato automaticamente da HACCP Manager — \(generatedLine)"
                left.draw(at: CGPoint(x: margin, y: footerY), withAttributes: attrs)
                let pageStr = "Pag. \(pageIndex)"
                let w = (pageStr as NSString).size(withAttributes: attrs).width
                pageStr.draw(at: CGPoint(x: pageRect.width - margin - w, y: footerY), withAttributes: attrs)
            }

            func startPage(isFirst: Bool) {
                if pageIndex > 0, !omitBuiltInFooter { drawFooterOnCurrentPage() }
                context.beginPage()
                pageIndex += 1
                y = margin
                if isFirst {
                    drawMainHeader(
                        restaurant: restaurantName,
                        title: reportTitle,
                        period: periodLine,
                        generated: generatedLine,
                        y: &y
                    )
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                        .foregroundColor: UIColor.darkGray
                    ]
                    "\(reportTitle) — continua (pag. \(pageIndex))".draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
                    y += 20
                }
            }

            @discardableResult
            func ensureSpace(_ needed: CGFloat) -> Bool {
                if y + needed <= bottomLimit { return false }
                startPage(isFirst: false)
                return true
            }

            startPage(isFirst: true)

            for section in sections {
                ensureSpace(28)
                let secAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: UIColor.black
                ]
                section.title.draw(at: CGPoint(x: margin, y: y), withAttributes: secAttrs)
                y += 22

                y = drawTableSection(
                    cg: context.cgContext,
                    headers: section.headers,
                    rows: section.rows,
                    y: y,
                    bottomLimit: bottomLimit,
                    bodyFontSize: bodyFontSize,
                    ensureSpace: { ensureSpace($0) }
                )
            }

            if !omitBuiltInFooter { drawFooterOnCurrentPage() }
        }
    }

    private static func drawMainHeader(
        restaurant: String,
        title: String,
        period: String,
        generated: String,
        y: inout CGFloat
    ) {
        let attrsTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let attrsSub: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        restaurant.draw(at: CGPoint(x: margin, y: y), withAttributes: attrsTitle)
        y += 22
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attrsSub)
        y += 16
        "Periodo: \(period)".draw(at: CGPoint(x: margin, y: y), withAttributes: attrsSub)
        y += 14
        "Data generazione: \(generated)".draw(at: CGPoint(x: margin, y: y), withAttributes: attrsSub)
        y += 18
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.setStrokeColor(UIColor.lightGray.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: margin, y: y))
            ctx.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            ctx.strokePath()
        }
        y += 12
    }

    private static func drawTableSection(
        cg: CGContext,
        headers: [String],
        rows: [[PDFTableCell]],
        y startY: CGFloat,
        bottomLimit: CGFloat,
        bodyFontSize: CGFloat,
        ensureSpace: (CGFloat) -> Bool
    ) -> CGFloat {
        var y = startY
        let contentWidth = pageRect.width - margin * 2
        let colWidths = computeColumnWidths(headers: headers, totalWidth: contentWidth)
        let headerH: CGFloat = 28
        let pad: CGFloat = 4

        func drawHeaderRow() {
            var x = margin
            cg.setFillColor(UIColor(white: 0.94, alpha: 1).cgColor)
            cg.fill(CGRect(x: margin, y: y, width: contentWidth, height: headerH))
            let headerFont = min(7, bodyFontSize + 0.5)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: headerFont, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            for (idx, h) in headers.enumerated() {
                let w = colWidths[safe: idx] ?? 60
                let rect = CGRect(x: x + pad, y: y + pad, width: w - pad * 2, height: headerH - pad * 2)
                (h as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                x += w
            }
            cg.setStrokeColor(UIColor.lightGray.cgColor)
            cg.stroke(CGRect(x: margin, y: y, width: contentWidth, height: headerH))
            y += headerH
        }

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .regular),
            .foregroundColor: UIColor.black
        ]

        _ = ensureSpace(headerH + 30)
        drawHeaderRow()

        if rows.isEmpty {
            _ = ensureSpace(30)
            let emptyRowH: CGFloat = 32
            let rect = CGRect(x: margin + pad, y: y + pad, width: contentWidth - pad * 2, height: emptyRowH - pad * 2)
            (HACCPRegisterCopy.noActivityInPeriod as NSString).draw(
                with: rect,
                options: [.usesLineFragmentOrigin],
                attributes: bodyAttrs,
                context: nil
            )
            cg.stroke(CGRect(x: margin, y: y, width: contentWidth, height: emptyRowH))
            y += emptyRowH
            return y
        }

        for row in rows {
            var rowH: CGFloat = 24
            for (idx, cell) in row.enumerated() {
                let cellW = (colWidths[safe: idx] ?? 60) - pad * 2
                switch cell {
                case .text(let s):
                    let bounding = (s as NSString).boundingRect(
                        with: CGSize(width: max(cellW, 24), height: 600),
                        options: [.usesLineFragmentOrigin],
                        attributes: bodyAttrs,
                        context: nil
                    )
                    rowH = max(rowH, min(160, ceil(bounding.height) + pad * 2 + 4))
                case .image(let data):
                    if let data, UIImage(data: data) != nil {
                        rowH = max(rowH, 48)
                    }
                }
            }

            if ensureSpace(rowH + 4) {
                drawHeaderRow()
            }

            var x = margin
            for (idx, cell) in row.enumerated() {
                let w = colWidths[safe: idx] ?? 60
                let cellRect = CGRect(x: x, y: y, width: w, height: rowH)
                cg.setStrokeColor(UIColor(white: 0.88, alpha: 1).cgColor)
                cg.stroke(cellRect)

                switch cell {
                case .text(let s):
                    let textRect = CGRect(x: x + pad, y: y + pad, width: w - pad * 2, height: rowH - pad * 2)
                    (s as NSString).draw(
                        with: textRect,
                        options: [.usesLineFragmentOrigin],
                        attributes: bodyAttrs,
                        context: nil
                    )
                case .image(let data):
                    if let data, let image = UIImage(data: data) {
                        let maxSide: CGFloat = 36
                        let aspect = image.size.width / max(image.size.height, 1)
                        var iw = maxSide
                        var ih = maxSide / max(aspect, 0.01)
                        if ih > maxSide { ih = maxSide; iw = ih * aspect }
                        let ix = x + (w - iw) / 2
                        let iy = y + (rowH - ih) / 2
                        image.draw(in: CGRect(x: ix, y: iy, width: iw, height: ih))
                    } else {
                        ("—" as NSString).draw(at: CGPoint(x: x + pad, y: y + pad), withAttributes: bodyAttrs)
                    }
                }
                x += w
            }
            y += rowH
        }

        return y
    }

    private static func computeColumnWidths(headers: [String], totalWidth: CGFloat) -> [CGFloat] {
        guard !headers.isEmpty else { return [totalWidth] }
        let fallback = totalWidth / CGFloat(headers.count)
        let weights: [CGFloat] = headers.map { h in
            let s = h.lowercased()
            if s.contains("checklist") || s.contains("note") || s.contains("eventi") || s.contains("azione") || s.contains("entità") {
                return 2.2
            }
            if s.contains("foto") { return 1.3 }
            if s.contains("operatore") || s.contains("fornitore") || s.contains("prodotto") {
                return 1.6
            }
            if s.contains("data") || s.contains("ora") || s.contains("timestamp") {
                return 1.4
            }
            if s.contains("lotto") || s.contains("stato") || s.contains("esito") {
                return 1.1
            }
            return 1.0
        }
        let totalWeight = max(weights.reduce(0, +), 0.01)
        var widths = weights.map { max(42, totalWidth * ($0 / totalWeight)) }
        let sum = widths.reduce(0, +)
        if sum > 0 {
            let scale = totalWidth / sum
            widths = widths.map { max(36, $0 * scale) }
        }
        let finalSum = widths.reduce(0, +)
        if abs(finalSum - totalWidth) > 0.5, let last = widths.indices.last {
            widths[last] += (totalWidth - finalSum)
        }
        return widths.map { $0.isFinite && $0 > 0 ? $0 : fallback }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
