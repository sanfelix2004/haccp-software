import UIKit

enum ProductionLabelBitmapRenderer {

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
            corner: settings.qrCorner
        )
        let qrReserve = settings.showQRCode && settings.qrCorner.reservesHorizontalColumn
            ? CGFloat(LabelQRCodeLayout.reservedColumnDots(
                cellSize: cell,
                payload: payload,
                settings: settings,
                corner: settings.qrCorner
            ))
            : 0

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            let left: CGFloat = settings.qrCorner.reservesLeftColumn
                ? profile.contentPadding + qrReserve
                : profile.contentPadding
            let maxTextWidth = CGFloat(width) - left
                - (settings.qrCorner.reservesRightColumn ? qrReserve : 0)
                - profile.contentPadding

            let lines = ProductionLabelPrintContent.fittingPrintLines(
                for: label,
                settings: settings,
                restaurantName: restaurantName,
                maxHeight: CGFloat(height),
                maxTextWidth: maxTextWidth
            )

            var y: CGFloat = profile.contentPadding
            for line in lines {
                guard y < CGFloat(height) - profile.contentPadding else { break }
                let font = line.bold
                    ? UIFont.boldSystemFont(ofSize: line.fontSize)
                    : UIFont.systemFont(ofSize: line.fontSize)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let remainingHeight = CGFloat(height) - y - profile.contentPadding
                guard remainingHeight > 4 else { break }
                let rect = CGRect(x: left, y: y, width: maxTextWidth, height: remainingHeight)
                let bounding = (line.text as NSString).boundingRect(
                    with: CGSize(width: maxTextWidth, height: remainingHeight),
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: attrs,
                    context: nil
                )
                (line.text as NSString).draw(
                    with: rect,
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: attrs,
                    context: nil
                )
                y += min(max(bounding.height, font.lineHeight), remainingHeight) + profile.lineGap
            }

            if settings.showQRCode,
               let qr = ProductionLabelQRService.image(
                   from: payload,
                   dimension: CGFloat(max(
                       profile.minPrintDots,
                       LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload)
                   ))
               ) {
                LabelQRCodeLayout.drawQR(
                    qr,
                    in: cg,
                    settings: settings,
                    payload: payload,
                    labelWidth: CGFloat(width),
                    labelHeight: CGFloat(height)
                )
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
                if gray < 128 {
                    let byteIndex = y * widthBytes + (x / 8)
                    let bit = 7 - (x % 8)
                    raster[byteIndex] |= UInt8(1 << bit)
                }
            }
        }
        return raster
    }
}
