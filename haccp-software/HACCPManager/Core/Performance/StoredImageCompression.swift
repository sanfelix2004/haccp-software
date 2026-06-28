//
//  StoredImageCompression.swift
//  Normalizza JPEG prima del salvataggio e in fase di archivio.
//

import UIKit

enum StoredImageCompression {

    static func preparedForStorage(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return data }
        return ImageProcessor.preparedJPEGData(
            from: data,
            maxPixel: PerformanceConfig.imageMaxPixelDimension,
            quality: PerformanceConfig.imageJPEGQuality
        ) ?? data
    }

    static func preparedForArchive(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return data }
        return ImageProcessor.preparedJPEGData(
            from: data,
            maxPixel: PerformanceConfig.archiveThumbnailMaxPixel,
            quality: PerformanceConfig.archiveJPEGQuality
        ) ?? data
    }

    /// JPEG ottimizzato per Groq Vision (ritaglio stampa + contrasto + varianti).
    static func preparedForGroqVision(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return nil }
        if let prepared = GroqVisionImagePreprocessor.prepare(from: data) {
            return prepared.stampFocusJPEG
        }
        return ImageProcessor.preparedJPEGData(
            from: data,
            maxPixel: PerformanceConfig.groqVisionMaxPixel,
            quality: PerformanceConfig.groqVisionJPEGQuality
        )
    }
}
