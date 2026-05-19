//
//  ImageProcessor.swift
//  Ridimensionamento e compressione allegati foto.
//

import UIKit

enum ImageProcessor {

    static func preparedJPEGData(
        from image: UIImage,
        maxPixel: CGFloat = PerformanceConfig.imageMaxPixelDimension,
        quality: CGFloat = PerformanceConfig.imageJPEGQuality
    ) -> Data? {
        let scaled = downscaled(image, maxPixel: maxPixel)
        return scaled.jpegData(compressionQuality: quality)
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
