import UIKit
import PDFKit

/// Aggiunge footer ufficiale e numerazione «Pagina X di Y» mantenendo il contenuto vettoriale.
enum HACCPPDFOfficialFooterStamper {
  private static let footerFontSize: CGFloat = 7.5
  private static let footerAttrs: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: footerFontSize, weight: .medium),
    .foregroundColor: UIColor.darkGray
  ]

  static func stamp(data: Data, generatedAt: Date, officialDocumentId: String) -> Data? {
    guard let src = PDFDocument(data: data), src.pageCount > 0 else { return nil }
    let pageCount = src.pageCount
    guard let firstPage = src.page(at: 0) else { return nil }
    let pageRect = firstPage.bounds(for: .mediaBox)
    let margin = HACCPPDFPageLayout.margin
    let bandTop = pageRect.height - margin - HACCPPDFPageLayout.officialFooterBandHeight

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

        // Separatore sopra la fascia footer (mai sovrapposto al corpo se il renderer rispetta contentBottomY).
        ctx.cgContext.setStrokeColor(UIColor(white: 0.82, alpha: 1).cgColor)
        ctx.cgContext.setLineWidth(0.5)
        ctx.cgContext.move(to: CGPoint(x: margin, y: bandTop - 4))
        ctx.cgContext.addLine(to: CGPoint(x: pageRect.width - margin, y: bandTop - 4))
        ctx.cgContext.strokePath()

        let footerLeft = "Documento ufficiale HACCP — \(officialDocumentId) — generato il \(gen)"
        let footerRight = "Pagina \(i + 1) di \(pageCount)"
        let textY = bandTop + 2
        let leftMaxWidth = pageRect.width - margin * 2 - 90
        let leftRect = CGRect(x: margin, y: textY, width: max(leftMaxWidth, 120), height: HACCPPDFPageLayout.officialFooterBandHeight)
        (footerLeft as NSString).draw(
          with: leftRect,
          options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
          attributes: footerAttrs,
          context: nil
        )
        let rightWidth = (footerRight as NSString).size(withAttributes: footerAttrs).width
        (footerRight as NSString).draw(
          at: CGPoint(x: pageRect.width - margin - rightWidth, y: textY),
          withAttributes: footerAttrs
        )
      }
    }
  }
}
