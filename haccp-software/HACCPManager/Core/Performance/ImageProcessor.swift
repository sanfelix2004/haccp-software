//
//  ImageProcessor.swift
//  Ridimensionamento e compressione allegati foto (Image I/O — basso uso RAM).
//

import ImageIO
import UIKit

enum ImageProcessor {

    /// Decodifica downsampled via Image I/O — non carica l'immagine full-res in RAM.
    static func downsampledImage(
        from data: Data,
        maxPixel: CGFloat = PerformanceConfig.imageMaxPixelDimension
    ) -> UIImage? {
        guard !data.isEmpty else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }
        let maxDimension = max(1, Int(maxPixel.rounded()))
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    static func preparedJPEGData(
        from image: UIImage,
        maxPixel: CGFloat = PerformanceConfig.imageMaxPixelDimension,
        quality: CGFloat = PerformanceConfig.imageJPEGQuality
    ) -> Data? {
        let scaled = downscaled(image, maxPixel: maxPixel)
        return scaled.jpegData(compressionQuality: quality)
    }

    static func preparedJPEGData(
        from data: Data,
        maxPixel: CGFloat = PerformanceConfig.imageMaxPixelDimension,
        quality: CGFloat = PerformanceConfig.imageJPEGQuality
    ) -> Data? {
        guard let image = downsampledImage(from: data, maxPixel: maxPixel) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }

    static func downscaled(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxPixel, longest > 0 else { return image }

        let scale = maxPixel / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
