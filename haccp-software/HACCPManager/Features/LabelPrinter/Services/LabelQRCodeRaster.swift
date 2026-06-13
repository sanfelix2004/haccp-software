import UIKit

enum LabelQRCodeRaster {

    /// Raster monocromatico 1 bit per comando TSPL BITMAP, con quiet zone bianca.
    static func monochromeRaster(for payload: String, sizeDots: Int) -> (data: Data, widthBytes: Int, heightDots: Int)? {
        guard sizeDots >= LabelQRCodeLayout.minPrintDots else { return nil }

        let canvas = sizeDots
        let qrDraw = max(LabelQRCodeLayout.minPrintDots - 16, Int(Double(canvas) * 0.78))
        let offset = (canvas - qrDraw) / 2

        guard let cgImage = ProductionLabelQRService.cgImage(from: payload, dimension: CGFloat(qrDraw)) else {
            return nil
        }

        let width = canvas
        let height = canvas
        let widthBytes = (width + 7) / 8
        var pixels = [UInt8](repeating: 255, count: width * height)

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)
        ctx.draw(cgImage, in: CGRect(x: offset, y: offset, width: qrDraw, height: qrDraw))

        var raster = Data(repeating: 0, count: widthBytes * height)
        for y in 0..<height {
            for x in 0..<width {
                if pixels[y * width + x] < 128 {
                    let byteIndex = y * widthBytes + (x / 8)
                    let bit = 7 - (x % 8)
                    raster[byteIndex] |= UInt8(1 << bit)
                }
            }
        }
        return (raster, widthBytes, height)
    }
}
