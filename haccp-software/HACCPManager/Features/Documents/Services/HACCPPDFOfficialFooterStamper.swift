import UIKit
import PDFKit

/// Aggiunge footer ufficiale e numerazione «Pagina X di Y» mantenendo il contenuto vettoriale.
enum HACCPPDFOfficialFooterStamper {
    static func stamp(data: Data, generatedAt: Date, officialDocumentId: String) -> Data? {
        guard let src = PDFDocument(data: data), src.pageCount > 0 else { return nil }
        let pageCount = src.pageCount
        guard let firstPage = src.page(at: 0) else { return nil }
        let pageRect = firstPage.bounds(for: .mediaBox)

        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        df.dateStyle = .medium
        df.timeStyle = .medium
        let gen = df.string(from: generatedAt)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            for i in 0..<pageCount {
                ctx.beginPage()
                guard let page = src.page(at: i) else { continue }
                ctx.cgContext.saveGState()
                let media = page.bounds(for: .mediaBox)
                let sx = pageRect.width / max(media.width, 1)
                let sy = pageRect.height / max(media.height, 1)
                ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                ctx.cgContext.scaleBy(x: sx, y: sy)
                page.draw(with: .mediaBox, to: ctx.cgContext)
                ctx.cgContext.restoreGState()

                let footerLeft = "Documento ufficiale HACCP — \(officialDocumentId) — generato il \(gen)"
                let footerRight = "Pagina \(i + 1) di \(pageCount)"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7.5, weight: .medium),
                    .foregroundColor: UIColor.darkGray
                ]
                let y: CGFloat = pageRect.height - 26
                (footerLeft as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: attrs)
                let w = (footerRight as NSString).size(withAttributes: attrs).width
                (footerRight as NSString).draw(at: CGPoint(x: pageRect.width - 36 - w, y: y), withAttributes: attrs)
            }
        }
    }
}
