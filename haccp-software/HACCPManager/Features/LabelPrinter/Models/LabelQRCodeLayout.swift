import Foundation
import UIKit

enum LabelQRCodeRotation: Int, Codable, CaseIterable, Identifiable {
    case r0 = 0
    case r90 = 90
    case r180 = 180
    case r270 = 270

    var id: Int { rawValue }

    var label: String { "\(rawValue)°" }

    var radians: CGFloat { CGFloat(rawValue) * .pi / 180 }
}

enum LabelQRCodeCorner: String, Codable, CaseIterable, Identifiable {
    case topRight
    case topLeft
    case bottomRight
    case bottomLeft

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topRight: return "Alto destra"
        case .topLeft: return "Alto sinistra"
        case .bottomRight: return "Basso destra"
        case .bottomLeft: return "Basso sinistra"
        }
    }

    var reservesRightColumn: Bool {
        self == .topRight || self == .bottomRight
    }

    var reservesLeftColumn: Bool {
        self == .topLeft || self == .bottomLeft
    }

    var reservesHorizontalColumn: Bool {
        reservesRightColumn || reservesLeftColumn
    }
}

enum LabelQRCodeLayout {

    static let marginDots = 8
    static let minCellSize = 3
    static let preferredCellSize = 4
    static let minPrintDots = 114

    /// Verifica se il QR entra nell'etichetta con cell size minimo scansionabile.
    static func fitsOnLabel(
        payload: String,
        cellSize: Int,
        labelWidth: Int = ClabelLabelDimensions.widthDots,
        labelHeight: Int = ClabelLabelDimensions.heightDots,
        corner: LabelQRCodeCorner = .bottomRight
    ) -> Bool {
        let cell = max(minCellSize, cellSize)
        let size = printSizeDots(cellSize: cell, payload: payload)
        guard size >= minPrintDots else { return false }
        let (x, y) = origin(
            corner: corner,
            labelWidth: labelWidth,
            labelHeight: labelHeight,
            qrSize: size
        )
        return x >= marginDots / 2
            && y >= marginDots / 2
            && x + size <= labelWidth - marginDots / 2
            && y + size <= labelHeight - marginDots / 2
    }

    /// Stima moduli QR — delegato a ProductionLabelQRService (conteggio reale via CoreImage).
    static func estimatedModuleCount(for payload: String) -> Int {
        ProductionLabelQRService.moduleCount(for: payload)
    }

    /// Dimensione reale stimata del QR stampato (dots).
    static func printSizeDots(cellSize: Int, payload: String) -> Int {
        let cell = max(minCellSize, min(8, cellSize))
        return ProductionLabelQRService.moduleCount(for: payload) * cell
    }

    /// Dimensione sicura per layout (anteprima / riserva testo).
    static func layoutBoxDots(cellSize: Int, payload: String) -> Int {
        printSizeDots(cellSize: cellSize, payload: payload) + 4
    }

    /// Sceglie la cella più grande possibile (QR più leggibile).
    static func clampedCellSize(
        _ cellSize: Int,
        payload: String,
        labelWidth: Int = ClabelLabelDimensions.widthDots,
        labelHeight: Int = ClabelLabelDimensions.heightDots,
        corner: LabelQRCodeCorner
    ) -> Int {
        let upper = min(8, max(cellSize, preferredCellSize))
        for cell in stride(from: upper, through: minCellSize, by: -1) {
            let size = printSizeDots(cellSize: cell, payload: payload)
            let (x, y) = origin(
                corner: corner,
                labelWidth: labelWidth,
                labelHeight: labelHeight,
                qrSize: size
            )
            if x >= marginDots / 2,
               y >= marginDots / 2,
               x + size <= labelWidth - marginDots / 2,
               y + size <= labelHeight - marginDots / 2,
               size >= minPrintDots {
                return cell
            }
        }
        return minCellSize
    }

    static func reservedColumnDots(cellSize: Int, payload: String, corner: LabelQRCodeCorner) -> Int {
        guard corner.reservesHorizontalColumn else { return 0 }
        let cell = clampedCellSize(cellSize, payload: payload, corner: corner)
        return layoutBoxDots(cellSize: cell, payload: payload) + 6
    }

    static func origin(
        corner: LabelQRCodeCorner,
        labelWidth: Int,
        labelHeight: Int,
        qrSize: Int,
        margin: Int = marginDots
    ) -> (x: Int, y: Int) {
        let maxX = max(margin, labelWidth - qrSize - margin)
        let maxY = max(margin, labelHeight - qrSize - margin)
        switch corner {
        case .topRight: return (maxX, margin)
        case .topLeft: return (margin, margin)
        case .bottomRight: return (maxX, maxY)
        case .bottomLeft: return (margin, maxY)
        }
    }

    static func rect(
        corner: LabelQRCodeCorner,
        labelWidth: CGFloat,
        labelHeight: CGFloat,
        qrSize: CGFloat,
        margin: CGFloat = CGFloat(marginDots)
    ) -> CGRect {
        let (x, y) = origin(
            corner: corner,
            labelWidth: Int(labelWidth),
            labelHeight: Int(labelHeight),
            qrSize: Int(qrSize),
            margin: Int(margin)
        )
        return CGRect(x: CGFloat(x), y: CGFloat(y), width: qrSize, height: qrSize)
    }

    static func payload(for label: ProductionLabelRecord, restaurantName: String? = nil) -> String {
        ProductionLabelQRService.printPayload(for: label, restaurantName: restaurantName)
    }

    static func drawQR(
        _ qr: UIImage,
        in context: CGContext,
        settings: LabelPrinterSettings,
        payload: String,
        labelWidth: CGFloat,
        labelHeight: CGFloat
    ) {
        let cell = clampedCellSize(
            settings.qrCellSize,
            payload: payload,
            corner: settings.qrCorner
        )
        let qrSize = CGFloat(max(
            LabelQRCodeLayout.minPrintDots,
            LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload)
        ))
        guard qrSize >= 1 else { return }
        let rect = self.rect(
            corner: settings.qrCorner,
            labelWidth: labelWidth,
            labelHeight: labelHeight,
            qrSize: qrSize
        )
        let center = CGPoint(x: rect.midX, y: rect.midY)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: settings.qrRotation.radians)
        qr.draw(in: CGRect(x: -qrSize / 2, y: -qrSize / 2, width: qrSize, height: qrSize))
        context.restoreGState()
    }
}

extension LabelQRCodeCorner {
    func origin(labelWidth: Int, labelHeight: Int, qrBox: Int, margin: Int = LabelQRCodeLayout.marginDots) -> (x: Int, y: Int) {
        LabelQRCodeLayout.origin(corner: self, labelWidth: labelWidth, labelHeight: labelHeight, qrSize: qrBox, margin: margin)
    }

    func rect(labelWidth: CGFloat, labelHeight: CGFloat, qrSize: CGFloat, margin: CGFloat = CGFloat(LabelQRCodeLayout.marginDots)) -> CGRect {
        LabelQRCodeLayout.rect(corner: self, labelWidth: labelWidth, labelHeight: labelHeight, qrSize: qrSize, margin: margin)
    }
}
