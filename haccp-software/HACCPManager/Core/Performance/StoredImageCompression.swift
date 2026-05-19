//
//  StoredImageCompression.swift
//  Normalizza JPEG prima del salvataggio e in fase di archivio.
//

import UIKit

enum StoredImageCompression {

    static func preparedForStorage(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty, let image = UIImage(data: data) else { return data }
        return ImageProcessor.preparedJPEGData(
            from: image,
            maxPixel: PerformanceConfig.imageMaxPixelDimension,
            quality: PerformanceConfig.imageJPEGQuality
        ) ?? data
    }

    static func preparedForArchive(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty, let image = UIImage(data: data) else { return data }
        return ImageProcessor.preparedJPEGData(
            from: image,
            maxPixel: PerformanceConfig.archiveThumbnailMaxPixel,
            quality: PerformanceConfig.archiveJPEGQuality
        ) ?? data
    }
}
