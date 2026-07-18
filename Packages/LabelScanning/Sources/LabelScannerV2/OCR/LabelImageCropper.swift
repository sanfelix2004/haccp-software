import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Genera ritagli dell'etichetta per un secondo passaggio OCR quando la lettura full-frame è incompleta.
///
/// Tipico: stampo inkjet / lotto / scadenza concentrati in una zona (basso, centro) mentre
/// packaging e ingredienti “rumore” riempiono il resto della foto.
enum LabelImageCropper {
    struct Region: Sendable {
        /// Normale [0,1], origine in alto a sinistra (come UIKit / CGImage).
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let name: String
    }

    /// Ritagli geometrici orientati alle zone tipiche degli stampi.
    static let defaultRetryRegions: [Region] = [
        Region(x: 0.12, y: 0.22, width: 0.76, height: 0.56, name: "centerStamp"),
        Region(x: 0.05, y: 0.48, width: 0.90, height: 0.48, name: "bottomBand"),
        Region(x: 0.05, y: 0.00, width: 0.90, height: 0.52, name: "topBand"),
        Region(x: 0.18, y: 0.55, width: 0.64, height: 0.40, name: "bottomCenter")
    ]

    /// Restituisce JPEG dei ritagli (salta regioni troppo piccole o non decodificabili).
    static func makeRetryCrops(from imageData: Data, regions: [Region] = defaultRetryRegions) -> [Data] {
        guard let cgImage = decodeCGImage(from: imageData) else { return [] }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > 32, h > 32 else { return [] }

        var crops: [Data] = []
        crops.reserveCapacity(regions.count)

        for region in regions {
            let rect = CGRect(
                x: region.x * w,
                y: region.y * h,
                width: region.width * w,
                height: region.height * h
            ).integral
            guard rect.width >= 24, rect.height >= 24 else { continue }
            guard let cropped = cgImage.cropping(to: clamped(rect, toWidth: w, height: h)) else { continue }
            if let jpeg = encodeJPEG(cropped, quality: 0.92) {
                crops.append(jpeg)
            }
        }
        return crops
    }

    private static func clamped(_ rect: CGRect, toWidth w: CGFloat, height h: CGFloat) -> CGRect {
        let x = max(0, min(rect.origin.x, w - 1))
        let y = max(0, min(rect.origin.y, h - 1))
        let maxW = w - x
        let maxH = h - y
        return CGRect(
            x: x,
            y: y,
            width: min(rect.width, maxW),
            height: min(rect.height, maxH)
        )
    }

    private static func decodeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
