import UIKit

enum ProductionLabelBitmapRenderer {

    static func raster(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        restaurantName: String? = nil
    ) -> Data {
        let width = ClabelLabelDimensions.printHeadWidthDots
        let height = ClabelLabelDimensions.heightDots
        let widthBytes = ClabelLabelDimensions.widthBytes

        let payload = LabelQRCodeLayout.payload(for: label, restaurantName: restaurantName)
        let cell = LabelQRCodeLayout.clampedCellSize(
            settings.qrCellSize,
            payload: payload,
            corner: settings.qrCorner
        )
        let qrReserve = settings.showQRCode && settings.qrCorner.reservesHorizontalColumn
            ? CGFloat(LabelQRCodeLayout.reservedColumnDots(
                cellSize: cell,
                payload: payload,
                corner: settings.qrCorner
            ))
            : 0

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            var y: CGFloat = 8
            let left: CGFloat = settings.qrCorner.reservesLeftColumn ? 10 + qrReserve : 10
            let maxTextWidth = CGFloat(width) - left - (settings.qrCorner.reservesRightColumn ? qrReserve : 0) - 6

            func draw(_ text: String, font: UIFont, bold: Bool = false) {
                guard !text.isEmpty else { return }
                let f = bold ? UIFont.boldSystemFont(ofSize: font.pointSize) : font
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: f,
                    .foregroundColor: UIColor.black
                ]
                let rect = CGRect(x: left, y: y, width: maxTextWidth, height: 200)
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: maxTextWidth, height: 200),
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: attrs,
                    context: nil
                )
                (text as NSString).draw(
                    with: rect,
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: attrs,
                    context: nil
                )
                y += max(bounding.height, f.lineHeight) + 2
            }

            draw("HACCP", font: .boldSystemFont(ofSize: 9))
            if settings.showProductName {
                draw(label.productName.uppercased(), font: .boldSystemFont(ofSize: 14), bold: true)
            }
            if settings.showLotNumber, let lot = label.lotCode, !lot.isEmpty {
                draw("Lotto \(lot)", font: .systemFont(ofSize: 10))
            }
            if settings.showPrepDate {
                let d = label.productionDate.formatted(date: .abbreviated, time: .omitted)
                draw("Prod. \(d)", font: .systemFont(ofSize: 10))
            }
            if settings.showExpiryDate {
                let d = label.expiryDate.formatted(date: .abbreviated, time: .omitted)
                draw("Scad. \(d)", font: .systemFont(ofSize: 10))
            }
            if settings.showOperatorName {
                draw("Op. \(label.createdByNameSnapshot)", font: .systemFont(ofSize: 9))
            }
            if settings.showAllergenWarning, !label.allergenList.isEmpty {
                draw("Allergeni: \(label.allergenList.joined(separator: ", "))", font: .systemFont(ofSize: 8))
            }
            if let storage = label.storageInstructions, !storage.isEmpty {
                draw(storage, font: .systemFont(ofSize: 8))
            }

            if settings.showQRCode,
               let qr = ProductionLabelQRService.image(
                   from: payload,
                   dimension: CGFloat(max(
                       LabelQRCodeLayout.minPrintDots,
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
