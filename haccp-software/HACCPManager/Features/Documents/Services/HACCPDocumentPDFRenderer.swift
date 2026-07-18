import UIKit

enum PDFTableCell {
    case text(String)
    case image(Data?)
}

/// Generazione PDF professionale in italiano (intestazione ufficiale, tabelle, testo normativo, firme).
enum HACCPDocumentPDFRenderer {
    private static let margin: CGFloat = HACCPPDFPageLayout.margin
    private static let cellPad: CGFloat = 6
    private static let minDataRowHeight: CGFloat = 28
    private static let minKVRowHeight: CGFloat = 24

    private static let continuationBandHeight: CGFloat = 28

    /// Stato di impaginazione condiviso: unica fonte di verità per `y` (evita sovrapposizioni post page-break).
    private final class PageFlow {
        let pageRect: CGRect
        let contentBottomY: CGFloat
        var y: CGFloat
        private var beginPage: (_ isFirst: Bool) -> Void

        init(pageRect: CGRect, beginPage: @escaping (_ isFirst: Bool) -> Void) {
            self.pageRect = pageRect
            self.contentBottomY = HACCPPDFPageLayout.contentBottomY(pageRect: pageRect)
            self.y = margin
            self.beginPage = beginPage
        }

        func setBeginPage(_ handler: @escaping (_ isFirst: Bool) -> Void) {
            beginPage = handler
        }

        /// Se `y + needed` supera il limite, apre una nuova pagina.
        /// `startPage` aggiorna già `flow.y` dopo il banner di continuazione — non resettare qui.
        @discardableResult
        func ensureFits(_ needed: CGFloat) -> Bool {
            guard needed > 0 else { return false }
            if y + needed <= contentBottomY { return false }
            beginPage(false)
            return true
        }

        var contentWidth: CGFloat { pageRect.width - margin * 2 }

        /// Riserva spazio verticale atomico per intestazione tabella + riga dati (ripete header dopo page-break).
        func reserveTableRow(headerHeight: CGFloat, rowHeight: CGFloat, redrawHeader: () -> Void) {
            guard rowHeight > 0 else { return }
            if y + rowHeight <= contentBottomY { return }
            ensureFits(headerHeight + rowHeight)
            redrawHeader()
        }
    }

    private static func measuredTextHeight(
        _ text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        padding: CGFloat = 0
    ) -> CGFloat {
        let core = ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: width, height: 10_000),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            ).height
        )
        return core + padding
    }

    static func render(
        context documentContext: HACCPPDFDocumentContext,
        sections: [HACCPPDFSection],
        pageRect: CGRect = HACCPPDFPageLayout.a4Portrait,
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
            let flow = PageFlow(pageRect: pageRect, beginPage: { _ in })

            func drawBuiltInFooterIfNeeded() {
                guard !omitBuiltInFooter, pageIndex > 0 else { return }
                let bandTop = pageRect.height - margin - HACCPPDFPageLayout.officialFooterBandHeight
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7.5, weight: .regular),
                    .foregroundColor: UIColor.gray
                ]
                let left = "HACCP Manager — \(documentContext.officialDocumentId) — generato il \(generatedLine)"
                left.draw(at: CGPoint(x: margin, y: bandTop + 2), withAttributes: attrs)
                let pageStr = "Pag. \(pageIndex)"
                let w = (pageStr as NSString).size(withAttributes: attrs).width
                pageStr.draw(at: CGPoint(x: pageRect.width - margin - w, y: bandTop + 2), withAttributes: attrs)
            }

            func startPage(isFirst: Bool) {
                drawBuiltInFooterIfNeeded()
                context.beginPage()
                pageIndex += 1
                flow.y = margin
                if isFirst {
                    drawOfficialHeader(
                        context: documentContext,
                        generatedLine: generatedLine,
                        pageRect: pageRect,
                        flow: flow
                    )
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9.5, weight: .semibold),
                        .foregroundColor: UIColor.darkGray
                    ]
                    let continuation = "\(documentContext.reportTitle) — segue (pag. \(pageIndex))"
                    let bandRect = CGRect(
                        x: margin,
                        y: flow.y,
                        width: pageRect.width - margin * 2,
                        height: continuationBandHeight
                    )
                    (continuation as NSString).draw(
                        with: bandRect,
                        options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                        attributes: attrs,
                        context: nil
                    )
                    flow.y += continuationBandHeight
                }
            }

            flow.setBeginPage { isFirst in startPage(isFirst: isFirst) }
            startPage(isFirst: true)

            for section in sections {
                drawSection(
                    section,
                    cg: context.cgContext,
                    flow: flow,
                    bodyFontSize: bodyFontSize
                )
                flow.y += 10
            }

            if !omitBuiltInFooter { drawBuiltInFooterIfNeeded() }
        }
    }

    // MARK: - Header

    private static func drawOfficialHeader(
        context: HACCPPDFDocumentContext,
        generatedLine: String,
        pageRect: CGRect,
        flow: PageFlow
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

        HACCPRegisterCopy.officialDocumentBanner.draw(at: CGPoint(x: margin, y: flow.y), withAttributes: bannerAttrs)
        flow.y += 18

        context.reportTitle.draw(at: CGPoint(x: margin, y: flow.y), withAttributes: titleAttrs)
        flow.y += 24

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
            let lineH = max(13, ceilMetaLineHeight(value, width: pageRect.width - margin * 2 - labelWidth, attrs: subAttrs) + 2)
            flow.ensureFits(lineH)
            label.draw(at: CGPoint(x: margin, y: flow.y), withAttributes: labelAttrs)
            let valueRect = CGRect(
                x: margin + labelWidth,
                y: flow.y,
                width: pageRect.width - margin * 2 - labelWidth,
                height: lineH
            )
            (value as NSString).draw(
                with: valueRect,
                options: [.usesLineFragmentOrigin],
                attributes: subAttrs,
                context: nil
            )
            flow.y += lineH
        }

        flow.y += 4
        strokeHorizontalRule(at: flow.y, pageRect: pageRect)
        flow.y += 14
    }

    private static func ceilMetaLineHeight(_ value: String, width: CGFloat, attrs: [NSAttributedString.Key: Any]) -> CGFloat {
        ceil(
            (value as NSString).boundingRect(
                with: CGSize(width: width, height: 200),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            ).height
        )
    }

    private static func strokeHorizontalRule(at y: CGFloat, pageRect: CGRect) {
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
        flow: PageFlow,
        bodyFontSize: CGFloat
    ) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12.5, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.8, weight: .regular),
            .foregroundColor: UIColor.gray
        ]

        let titleH = measuredTextHeight(section.title, width: flow.contentWidth, attributes: titleAttrs, padding: 4)
        let subtitleText = section.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subtitleH: CGFloat = subtitleText.isEmpty
            ? 0
            : measuredTextHeight(subtitleText, width: flow.contentWidth, attributes: subAttrs, padding: 6)

        // Blocco atomico titolo + sottotitolo: mai spezzare tra le due righe.
        flow.ensureFits(titleH + subtitleH)

        section.title.draw(at: CGPoint(x: margin, y: flow.y), withAttributes: titleAttrs)
        flow.y += titleH

        if subtitleH > 0 {
            let rect = CGRect(x: margin, y: flow.y, width: flow.contentWidth, height: subtitleH)
            (subtitleText as NSString).draw(
                with: rect,
                options: [.usesLineFragmentOrigin],
                attributes: subAttrs,
                context: nil
            )
            flow.y += subtitleH
        }

        switch section.content {
        case .keyValueTable(let headers, let rows):
            drawTableSection(
                cg: cg,
                flow: flow,
                headers: headers,
                rows: rows,
                bodyFontSize: bodyFontSize,
                keyValueStyle: true
            )
        case .dataTable(let headers, let rows):
            drawTableSection(
                cg: cg,
                flow: flow,
                headers: headers,
                rows: rows,
                bodyFontSize: bodyFontSize,
                keyValueStyle: false
            )
        case .prose(let paragraphs):
            drawProse(paragraphs, flow: flow)
        case .signatures(let block):
            drawSignatures(block, flow: flow)
        }
    }

    private static func drawProse(_ paragraphs: [String], flow: PageFlow) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let width = flow.contentWidth

        for paragraph in paragraphs {
            let bounding = (paragraph as NSString).boundingRect(
                with: CGSize(width: width, height: 800),
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
            let blockH = ceil(bounding.height) + 10
            flow.ensureFits(blockH)
            let rect = CGRect(x: margin, y: flow.y, width: width, height: blockH)
            (paragraph as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            flow.y += blockH
        }
    }

    private static func drawSignatures(_ block: HACCPPDFSignatureBlock, flow: PageFlow) {
        drawProse([block.intro], flow: flow)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: UIColor.black
        ]
        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        for role in block.roles {
            flow.ensureFits(52)
            (role as NSString).draw(at: CGPoint(x: margin, y: flow.y), withAttributes: labelAttrs)
            flow.y += 16
            let line = "Firma: _________________________________    Data: ____ / ____ / ________"
            (line as NSString).draw(at: CGPoint(x: margin, y: flow.y), withAttributes: lineAttrs)
            flow.y += 28
        }
    }

    // MARK: - Tables

    private static func drawTableSection(
        cg: CGContext,
        flow: PageFlow,
        headers: [String],
        rows: [[PDFTableCell]],
        bodyFontSize: CGFloat,
        keyValueStyle: Bool
    ) {
        let contentWidth = flow.contentWidth
        let colWidths = computeColumnWidths(headers: headers, totalWidth: contentWidth, keyValueStyle: keyValueStyle)
        let baseHeaderMin: CGFloat = keyValueStyle ? 28 : 32
        let minRowH = keyValueStyle ? minKVRowHeight : minDataRowHeight

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .regular),
            .foregroundColor: UIColor.black
        ]

        func measureHeaderHeight() -> CGFloat {
            let headerFont = min(9.2, bodyFontSize + 0.4)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: headerFont, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            var maxH = baseHeaderMin
            for (idx, h) in headers.enumerated() {
                let cellW = (colWidths[safe: idx] ?? 60) - cellPad * 2
                let cellH = measuredTextHeight(
                    h,
                    width: max(cellW, 20),
                    attributes: attrs,
                    padding: cellPad * 2 + 2
                )
                maxH = max(maxH, cellH)
            }
            return maxH
        }

        func drawHeaderRow() {
            let headerH = measureHeaderHeight()
            var x = margin
            cg.setFillColor(UIColor(red: 0.91, green: 0.94, blue: 0.97, alpha: 1).cgColor)
            cg.fill(CGRect(x: margin, y: flow.y, width: contentWidth, height: headerH))
            let headerFont = min(9.2, bodyFontSize + 0.4)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: headerFont, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            for (idx, h) in headers.enumerated() {
                let w = colWidths[safe: idx] ?? 60
                let rect = CGRect(x: x + cellPad, y: flow.y + cellPad, width: w - cellPad * 2, height: headerH - cellPad * 2)
                (h as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                x += w
            }
            cg.setStrokeColor(UIColor(white: 0.72, alpha: 1).cgColor)
            cg.setLineWidth(0.6)
            cg.stroke(CGRect(x: margin, y: flow.y, width: contentWidth, height: headerH))
            flow.y += headerH
        }

        func measureRowHeight(_ row: [PDFTableCell]) -> CGFloat {
            var rowH = minRowH
            for (idx, cell) in row.enumerated() {
                let cellW = (colWidths[safe: idx] ?? 60) - cellPad * 2
                switch cell {
                case .text(let s):
                    rowH = max(
                        rowH,
                        measuredTextHeight(s, width: max(cellW, 20), attributes: bodyAttrs, padding: cellPad * 2 + 4)
                    )
                case .image(let data):
                    if let data, UIImage(data: data) != nil {
                        rowH = max(rowH, 56)
                    }
                }
            }
            return rowH
        }

        func drawDataRow(_ row: [PDFTableCell], rowIndex: Int, rowH: CGFloat) {
            if rowIndex.isMultiple(of: 2) {
                cg.setFillColor(UIColor(white: 0.98, alpha: 1).cgColor)
                cg.fill(CGRect(x: margin, y: flow.y, width: contentWidth, height: rowH))
            }

            var x = margin
            for (idx, cell) in row.enumerated() {
                let w = colWidths[safe: idx] ?? 60
                let cellRect = CGRect(x: x, y: flow.y, width: w, height: rowH)
                cg.setStrokeColor(UIColor(white: 0.86, alpha: 1).cgColor)
                cg.stroke(cellRect)

                switch cell {
                case .text(let s):
                    let textRect = CGRect(x: x + cellPad, y: flow.y + cellPad, width: w - cellPad * 2, height: rowH - cellPad * 2)
                    (s as NSString).draw(
                        with: textRect,
                        options: [.usesLineFragmentOrigin],
                        attributes: bodyAttrs,
                        context: nil
                    )
                case .image(let data):
                    if let data, let image = UIImage(data: data) {
                        let size: CGFloat = 44
                        let cropped = cropToSquare(image)
                        let ix = x + (w - size) / 2
                        let iy = flow.y + (rowH - size) / 2
                        cropped.draw(in: CGRect(x: ix, y: iy, width: size, height: size))
                    } else {
                        (HACCPRegisterCopy.notAvailable as NSString).draw(
                            at: CGPoint(x: x + cellPad, y: flow.y + cellPad),
                            withAttributes: bodyAttrs
                        )
                    }
                }
                x += w
            }
            flow.y += rowH
        }

        // Intestazione tabella: se non c'è spazio per header + almeno una riga, nuova pagina.
        let initialHeaderH = measureHeaderHeight()
        let minBodyAfterHeader: CGFloat = rows.isEmpty ? 34 : minRowH
        if flow.y + initialHeaderH + minBodyAfterHeader > flow.contentBottomY {
            flow.ensureFits(initialHeaderH + minBodyAfterHeader)
        }
        drawHeaderRow()

        if rows.isEmpty {
            let emptyRowH: CGFloat = 34
            flow.ensureFits(emptyRowH)
            let rect = CGRect(x: margin + cellPad, y: flow.y + cellPad, width: contentWidth - cellPad * 2, height: emptyRowH - cellPad * 2)
            (HACCPRegisterCopy.noActivityInPeriod as NSString).draw(
                with: rect,
                options: [.usesLineFragmentOrigin],
                attributes: bodyAttrs,
                context: nil
            )
            cg.stroke(CGRect(x: margin, y: flow.y, width: contentWidth, height: emptyRowH))
            flow.y += emptyRowH
            return
        }

        for (rowIndex, row) in rows.enumerated() {
            let rowH = measureRowHeight(row)

            // Riga atomica: se non entra intera, nuova pagina + re-intestazione colonne.
            flow.reserveTableRow(
                headerHeight: measureHeaderHeight(),
                rowHeight: rowH,
                redrawHeader: drawHeaderRow
            )

            drawDataRow(row, rowIndex: rowIndex, rowH: rowH)
        }
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

private func cropToSquare(_ image: UIImage) -> UIImage {
    guard let cgImage = image.cgImage else { return image }
    let side = min(cgImage.width, cgImage.height)
    let x = (cgImage.width - side) / 2
    let y = (cgImage.height - side) / 2
    let cropRect = CGRect(x: x, y: y, width: side, height: side)
    guard let croppedCgImage = cgImage.cropping(to: cropRect) else { return image }
    return UIImage(cgImage: croppedCgImage, scale: image.scale, orientation: image.imageOrientation)
}
