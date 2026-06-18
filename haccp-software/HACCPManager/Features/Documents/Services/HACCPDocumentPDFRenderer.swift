import UIKit

enum PDFTableCell {
    case text(String)
    case image(Data?)
}

/// Generazione PDF professionale in italiano (intestazione ufficiale, tabelle, testo normativo, firme).
enum HACCPDocumentPDFRenderer {
    private static let pageRect = CGRect(x: 0, y: 0, width: 842, height: 595)
    private static let margin: CGFloat = 40
    private static let footerReserve: CGFloat = 36

    static func render(
        context documentContext: HACCPPDFDocumentContext,
        sections: [HACCPPDFSection],
        omitBuiltInFooter: Bool = false,
        bodyFontSize: CGFloat = 9.2
    ) -> Data? {
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "it_IT")
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .short
        let generatedLine = dateFmt.string(from: documentContext.generatedAt)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            var pageIndex = 0
            var y: CGFloat = margin
            let bottomLimit = pageRect.height - margin - footerReserve

            func drawFooterOnCurrentPage() {
                guard !omitBuiltInFooter else { return }
                let footerY = pageRect.height - margin + 2
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7.5, weight: .regular),
                    .foregroundColor: UIColor.gray
                ]
                let left = "HACCP Manager — \(documentContext.officialDocumentId) — generato il \(generatedLine)"
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
                    drawOfficialHeader(context: documentContext, generatedLine: generatedLine, y: &y)
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9.5, weight: .semibold),
                        .foregroundColor: UIColor.darkGray
                    ]
                    "\(documentContext.reportTitle) — segue (pag. \(pageIndex))".draw(
                        at: CGPoint(x: margin, y: y),
                        withAttributes: attrs
                    )
                    y += 22
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
                y = drawSection(
                    section,
                    cg: context.cgContext,
                    y: y,
                    bottomLimit: bottomLimit,
                    bodyFontSize: bodyFontSize,
                    ensureSpace: { ensureSpace($0) }
                )
                y += 10
            }

            if !omitBuiltInFooter { drawFooterOnCurrentPage() }
        }
    }

    // MARK: - Header

    private static func drawOfficialHeader(
        context: HACCPPDFDocumentContext,
        generatedLine: String,
        y: inout CGFloat
    ) {
        let bannerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .heavy),
            .foregroundColor: UIColor(white: 0.15, alpha: 1)
        ]
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .semibold),
            .foregroundColor: UIColor(white: 0.35, alpha: 1)
        ]

        HACCPRegisterCopy.officialDocumentBanner.draw(at: CGPoint(x: margin, y: y), withAttributes: bannerAttrs)
        y += 18

        context.reportTitle.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 24

        let metaLines: [(String, String)] = [
            ("Esercizio", context.restaurantName),
            ("Sede", context.restaurantAddress.isEmpty ? HACCPRegisterCopy.notAvailable : context.restaurantAddress),
            ("Recapiti", context.restaurantContacts.isEmpty ? HACCPRegisterCopy.notAvailable : context.restaurantContacts),
            ("Responsabile HACCP", context.haccpManager.isEmpty ? HACCPRegisterCopy.notAvailable : context.haccpManager),
            ("Periodo di riferimento", context.periodLine),
            ("Data di redazione", context.reportDateLine),
            ("Generazione file", generatedLine),
            ("Identificativo documento", context.officialDocumentId),
            ("Riferimento normativo", HACCPPDFLegalBlocks.normativeReference)
        ]

        for (label, value) in metaLines {
            let labelWidth: CGFloat = 148
            label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            let valueRect = CGRect(
                x: margin + labelWidth,
                y: y,
                width: pageRect.width - margin * 2 - labelWidth,
                height: 80
            )
            (value as NSString).draw(
                with: valueRect,
                options: [.usesLineFragmentOrigin],
                attributes: subAttrs,
                context: nil
            )
            let h = (value as NSString).boundingRect(
                with: CGSize(width: valueRect.width, height: 200),
                options: [.usesLineFragmentOrigin],
                attributes: subAttrs,
                context: nil
            ).height
            y += max(13, ceil(h) + 2)
        }

        y += 4
        strokeHorizontalRule(at: y)
        y += 14
    }

    private static func strokeHorizontalRule(at y: CGFloat) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor(white: 0.78, alpha: 1).cgColor)
        ctx.setLineWidth(0.75)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        ctx.strokePath()
    }

    // MARK: - Sections

    private static func drawSection(
        _ section: HACCPPDFSection,
        cg: CGContext,
        y startY: CGFloat,
        bottomLimit: CGFloat,
        bodyFontSize: CGFloat,
        ensureSpace: (CGFloat) -> Bool
    ) -> CGFloat {
        var y = startY
        _ = ensureSpace(36)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12.5, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        section.title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 18

        if let subtitle = section.subtitle, !subtitle.isEmpty {
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8.8, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            let rect = CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 40)
            (subtitle as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: subAttrs, context: nil)
            y += 16
        }

        switch section.content {
        case .keyValueTable(let headers, let rows):
            y = drawTableSection(
                cg: cg,
                headers: headers,
                rows: rows,
                y: y,
                bottomLimit: bottomLimit,
                bodyFontSize: bodyFontSize,
                keyValueStyle: true,
                ensureSpace: ensureSpace
            )
        case .dataTable(let headers, let rows):
            y = drawTableSection(
                cg: cg,
                headers: headers,
                rows: rows,
                y: y,
                bottomLimit: bottomLimit,
                bodyFontSize: bodyFontSize,
                keyValueStyle: false,
                ensureSpace: ensureSpace
            )
        case .prose(let paragraphs):
            y = drawProse(paragraphs, y: y, bottomLimit: bottomLimit, ensureSpace: ensureSpace)
        case .signatures(let block):
            y = drawSignatures(block, y: y, bottomLimit: bottomLimit, ensureSpace: ensureSpace)
        }

        return y
    }

    private static func drawProse(
        _ paragraphs: [String],
        y startY: CGFloat,
        bottomLimit: CGFloat,
        ensureSpace: (CGFloat) -> Bool
    ) -> CGFloat {
        var y = startY
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let width = pageRect.width - margin * 2

        for paragraph in paragraphs {
            let bounding = (paragraph as NSString).boundingRect(
                with: CGSize(width: width, height: 800),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
            let blockH = ceil(bounding.height) + 10
            _ = ensureSpace(blockH)
            let rect = CGRect(x: margin, y: y, width: width, height: blockH)
            (paragraph as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            y += blockH
        }
        return y
    }

    private static func drawSignatures(
        _ block: HACCPPDFSignatureBlock,
        y startY: CGFloat,
        bottomLimit: CGFloat,
        ensureSpace: (CGFloat) -> Bool
    ) -> CGFloat {
        var y = startY
        y = drawProse([block.intro], y: y, bottomLimit: bottomLimit, ensureSpace: ensureSpace)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: UIColor.black
        ]
        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        for role in block.roles {
            _ = ensureSpace(52)
            (role as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
            y += 16
            let line = "Firma: _________________________________    Data: ____ / ____ / ________"
            (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: lineAttrs)
            y += 28
        }
        return y
    }

    // MARK: - Tables

    private static func drawTableSection(
        cg: CGContext,
        headers: [String],
        rows: [[PDFTableCell]],
        y startY: CGFloat,
        bottomLimit: CGFloat,
        bodyFontSize: CGFloat,
        keyValueStyle: Bool,
        ensureSpace: (CGFloat) -> Bool
    ) -> CGFloat {
        var y = startY
        let contentWidth = pageRect.width - margin * 2
        let colWidths = computeColumnWidths(headers: headers, totalWidth: contentWidth, keyValueStyle: keyValueStyle)
        let headerH: CGFloat = keyValueStyle ? 26 : 30
        let pad: CGFloat = 5

        func drawHeaderRow() {
            var x = margin
            cg.setFillColor(UIColor(red: 0.91, green: 0.94, blue: 0.97, alpha: 1).cgColor)
            cg.fill(CGRect(x: margin, y: y, width: contentWidth, height: headerH))
            let headerFont = min(9.2, bodyFontSize + 0.4)
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
            cg.setStrokeColor(UIColor(white: 0.72, alpha: 1).cgColor)
            cg.setLineWidth(0.6)
            cg.stroke(CGRect(x: margin, y: y, width: contentWidth, height: headerH))
            y += headerH
        }

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .regular),
            .foregroundColor: UIColor.black
        ]

        _ = ensureSpace(headerH + 34)
        drawHeaderRow()

        if rows.isEmpty {
            _ = ensureSpace(34)
            let emptyRowH: CGFloat = 34
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

        for (rowIndex, row) in rows.enumerated() {
            var rowH: CGFloat = keyValueStyle ? 22 : 26
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
                    rowH = max(rowH, min(180, ceil(bounding.height) + pad * 2 + 6))
                case .image(let data):
                    if let data, UIImage(data: data) != nil {
                        rowH = max(rowH, 52)
                    }
                }
            }

            if ensureSpace(rowH + 4) {
                drawHeaderRow()
            }

            if rowIndex.isMultiple(of: 2) {
                cg.setFillColor(UIColor(white: 0.98, alpha: 1).cgColor)
                cg.fill(CGRect(x: margin, y: y, width: contentWidth, height: rowH))
            }

            var x = margin
            for (idx, cell) in row.enumerated() {
                let w = colWidths[safe: idx] ?? 60
                let cellRect = CGRect(x: x, y: y, width: w, height: rowH)
                cg.setStrokeColor(UIColor(white: 0.86, alpha: 1).cgColor)
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
                        let maxSide: CGFloat = 42
                        let aspect = image.size.width / max(image.size.height, 1)
                        var iw = maxSide
                        var ih = maxSide / max(aspect, 0.01)
                        if ih > maxSide { ih = maxSide; iw = ih * aspect }
                        let ix = x + (w - iw) / 2
                        let iy = y + (rowH - ih) / 2
                        image.draw(in: CGRect(x: ix, y: iy, width: iw, height: ih))
                    } else {
                        (HACCPRegisterCopy.notAvailable as NSString).draw(at: CGPoint(x: x + pad, y: y + pad), withAttributes: bodyAttrs)
                    }
                }
                x += w
            }
            y += rowH
        }

        return y
    }

    private static func computeColumnWidths(headers: [String], totalWidth: CGFloat, keyValueStyle: Bool) -> [CGFloat] {
        guard !headers.isEmpty else { return [totalWidth] }
        let fallback = totalWidth / CGFloat(headers.count)
        if keyValueStyle, headers.count == 2 {
            return [totalWidth * 0.34, totalWidth * 0.66]
        }
        let weights: [CGFloat] = headers.map { h in
            let s = h.lowercased()
            if s.contains("checklist") || s.contains("note") || s.contains("annotaz") || s.contains("azione") || s.contains("motivo") || s.contains("dettaglio") {
                return 2.3
            }
            if s.contains("foto") || s.contains("documentazione") { return 1.25 }
            if s.contains("operatore") || s.contains("fornitore") || s.contains("prodotto") || s.contains("denominazione") {
                return 1.65
            }
            if s.contains("data") || s.contains("ora") { return 1.45 }
            if s.contains("lotto") || s.contains("stato") || s.contains("esito") || s.contains("range") {
                return 1.15
            }
            return 1.0
        }
        let totalWeight = max(weights.reduce(0, +), 0.01)
        var widths = weights.map { max(44, totalWidth * ($0 / totalWeight)) }
        let sum = widths.reduce(0, +)
        if sum > 0 {
            let scale = totalWidth / sum
            widths = widths.map { max(38, $0 * scale) }
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
