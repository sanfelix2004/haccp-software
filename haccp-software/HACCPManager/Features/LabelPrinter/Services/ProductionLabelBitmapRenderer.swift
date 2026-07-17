import UIKit

/// Raster 50×30: testo a sinistra, QR grande a destra, senza sovrapposizioni.
enum ProductionLabelBitmapRenderer {

    private static let textQRGap: CGFloat = 10

    static func raster(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        restaurantName: String? = nil
    ) -> Data {
        let spec = settings.labelSpec
        let profile = spec.layout
        let width = spec.widthDots
        let height = spec.heightDots
        let widthBytes = spec.widthBytes

        let payload = LabelQRCodeLayout.payload(for: label, restaurantName: restaurantName)
        let cell = LabelQRCodeLayout.clampedCellSize(
            settings.qrCellSize,
            payload: payload,
            settings: settings,
            corner: .topRight
        )
        let qrSize: CGFloat = settings.showQRCode
            ? CGFloat(min(
                profile.maxQRDots,
                max(
                    profile.minPrintDots,
                    LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload, settings: settings)
                )
            ))
            : 0

        let left = profile.contentPadding
        // Colonna testo limitata: gap fisso prima del QR.
        let textColumnCap = qrSize > 0
            ? CGFloat(width) * 0.55
            : CGFloat(width) - profile.contentPadding * 2
        let maxTextWidth = min(
            textColumnCap,
            CGFloat(width) - left - (qrSize > 0 ? qrSize + textQRGap + 24 : profile.contentPadding)
        )

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            let lines = ProductionLabelPrintContent.printLines(
                for: label,
                settings: settings,
                restaurantName: restaurantName
            )

            var y = profile.contentPadding + 2
            let maxY = CGFloat(height) - profile.contentPadding
            for line in lines {
                let font = line.bold
                    ? UIFont.boldSystemFont(ofSize: line.fontSize)
                    : UIFont.systemFont(ofSize: line.fontSize, weight: .medium)
                let lineHeight = ceil(font.lineHeight) + profile.lineGap
                guard y + lineHeight <= maxY else { break }

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let rect = CGRect(x: left, y: y, width: maxTextWidth, height: lineHeight)
                (line.text as NSString).draw(
                    with: rect,
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: attrs,
                    context: nil
                )
                y += lineHeight
            }

            if settings.showQRCode, qrSize >= 1,
               let qr = ProductionLabelQRService.image(from: payload, dimension: qrSize) {
                // Margine interno: QR non a filo bordo.
                let edgeInset = max(profile.contentPadding + 10, CGFloat(profile.qrMarginDots + 12))
                let flushRight = CGFloat(width) - qrSize - edgeInset
                let qx = max(left + maxTextWidth + textQRGap, flushRight - 18)
                let qy = max(edgeInset, (CGFloat(height) - qrSize) / 2)
                UIColor.white.setFill()
                cg.fill(CGRect(x: qx - 3, y: qy - 3, width: qrSize + 6, height: qrSize + 6))
                qr.draw(in: CGRect(x: qx, y: qy, width: qrSize, height: qrSize))
            }
        }

        return bitmapToRaster(image.cgImage, width: width, height: height, widthBytes: widthBytes)
    }

    private static func bitmapToRaster(_ cgImage: CGImage?, width: Int, height: Int, widthBytes: Int) -> Data {
        guard let cgImage else { return Data(repeating: 0, count: widthBytes * height) }

        var pixels = [UInt8](repeating: 255, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Data(repeating: 0, count: widthBytes * height)
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var raster = Data(repeating: 0, count: widthBytes * height)
        for y in 0..<height {
            for x in 0..<width {
                let gray = pixels[y * width + x]
                // CLABEL S1: bit 1 = bianco (non scalda). Invertiamo rispetto allo standard TSPL.
                if gray >= 128 {
                    let byteIndex = y * widthBytes + (x / 8)
                    let bit = 7 - (x % 8)
                    raster[byteIndex] |= UInt8(1 << bit)
                }
            }
        }
        return raster
    }
}
