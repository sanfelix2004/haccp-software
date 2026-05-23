//
//  ProductionLabelPDFExporter.swift
//  Export singola etichetta o batch in PDF.
//

import UIKit

enum ProductionLabelPDFExporter {

    static func export(labels: [ProductionLabelRecord], restaurantName: String) throws -> URL {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40
        let labelHeight: CGFloat = 200
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("etichette-haccp-\(UUID().uuidString.prefix(8)).pdf")

        try renderer.writePDF(to: url) { context in
            var y = margin
            context.beginPage()

            let title = "Etichette HACCP — \(restaurantName)"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.label
            ])
            y += 36

            for label in labels {
                if y + labelHeight > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
                drawLabel(label, in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: labelHeight))
                y += labelHeight + 16
            }
        }
        return url
    }

    private static func drawLabel(_ label: ProductionLabelRecord, in rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        UIColor.secondarySystemBackground.setFill()
        path.fill()
        UIColor.separator.setStroke()
        path.lineWidth = 1
        path.stroke()

        let inset = rect.insetBy(dx: 14, dy: 12)
        var textY = inset.minY

        func drawLine(_ text: String, font: UIFont, color: UIColor = .label) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            text.draw(at: CGPoint(x: inset.minX, y: textY), withAttributes: attrs)
            textY += font.lineHeight + 4
        }

        drawLine(label.productName.uppercased(), font: .boldSystemFont(ofSize: 16))
        if let lot = label.lotCode, !lot.isEmpty {
            drawLine("Lotto: \(lot)", font: .systemFont(ofSize: 11), color: .secondaryLabel)
        }
        drawLine(
            "Prod. \(label.productionDate.formatted(date: .abbreviated, time: .omitted)) · Scad. \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))",
            font: .systemFont(ofSize: 11)
        )
        drawLine("Operatore: \(label.createdByNameSnapshot)", font: .systemFont(ofSize: 10), color: .secondaryLabel)
        if let storage = label.storageInstructions, !storage.isEmpty {
            drawLine("Conservazione: \(storage)", font: .systemFont(ofSize: 10))
        }
        if !label.allergenList.isEmpty {
            drawLine("Allergeni: \(label.allergenList.joined(separator: ", "))", font: .systemFont(ofSize: 10), color: .systemRed)
        }

        if let qr = ProductionLabelQRService.image(from: label.qrPayload, dimension: 72) {
            qr.draw(in: CGRect(x: rect.maxX - 86, y: rect.minY + 20, width: 72, height: 72))
        }
    }
}
