import CoreImage
import UIKit

/// Prepara varianti ottimizzate per Groq Vision — zoom area stampa, contrasto, inversione su sfondo scuro.
enum GroqVisionImagePreprocessor {

    struct PreparedImages: Sendable {
        /// Ritaglio area stampa superiore (retro confezione, etichetta alta).
        let stampFocusJPEG: Data
        /// Ritaglio area stampa inferiore (tappi, fondo barattolo, base confezione).
        let stampBottomJPEG: Data
        /// Stessa area superiore con colori invertiti (testo bianco su sfondo scuro → nero su bianco).
        let stampInvertedJPEG: Data
        /// Stessa area inferiore invertita.
        let stampBottomInvertedJPEG: Data
        /// Inquadratura completa con contrasto leggero.
        let fullFrameJPEG: Data
    }

    /// Decodifica max 1536px, ritaglia e migliora prima di inviare a Groq.
    static func prepare(from imageData: Data) -> PreparedImages? {
        guard let base = ImageProcessor.downsampledImage(
            from: imageData,
            maxPixel: PerformanceConfig.groqVisionDecodeMaxPixel
        ) else { return nil }

        let stampFocus = enhanceContrast(
            cropStampRegion(from: base, centerYFraction: 0.34)
        )
        let stampBottom = enhanceContrast(
            cropStampRegion(from: base, centerYFraction: 0.72)
        )
        let stampInverted = invertColors(stampFocus)
        let stampBottomInverted = invertColors(stampBottom)
        let fullFrame = enhanceContrast(base)

        guard let stampJPEG = jpegData(stampFocus, maxPixel: PerformanceConfig.groqVisionMaxPixel),
              let bottomJPEG = jpegData(stampBottom, maxPixel: PerformanceConfig.groqVisionMaxPixel),
              let invertedJPEG = jpegData(stampInverted, maxPixel: PerformanceConfig.groqVisionMaxPixel),
              let bottomInvertedJPEG = jpegData(stampBottomInverted, maxPixel: PerformanceConfig.groqVisionMaxPixel),
              let fullJPEG = jpegData(fullFrame, maxPixel: PerformanceConfig.groqVisionMaxPixel) else {
            return nil
        }

        return PreparedImages(
            stampFocusJPEG: stampJPEG,
            stampBottomJPEG: bottomJPEG,
            stampInvertedJPEG: invertedJPEG,
            stampBottomInvertedJPEG: bottomInvertedJPEG,
            fullFrameJPEG: fullJPEG
        )
    }

    // MARK: - Crop

    /// Ritaglio centrato su una fascia verticale — lotto/data su retro confezione o tappo.
    private static func cropStampRegion(from image: UIImage, centerYFraction: CGFloat) -> UIImage {
        crop(
            image: image,
            widthFraction: 0.92,
            heightFraction: 0.48,
            centerYFraction: centerYFraction
        )
    }

    private static func crop(
        image: UIImage,
        widthFraction: CGFloat,
        heightFraction: CGFloat,
        centerYFraction: CGFloat
    ) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)

        let cropW = max(40, w * widthFraction)
        let cropH = max(40, h * heightFraction)
        let originX = max(0, (w - cropW) / 2)
        let centerY = h * centerYFraction
        let originY = max(0, min(h - cropH, centerY - cropH / 2))

        let rect = CGRect(x: originX, y: originY, width: cropW, height: cropH).integral
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    // MARK: - Filters

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private static func enhanceContrast(_ image: UIImage) -> UIImage {
        applyFilters(to: image) { input in
            guard let controls = CIFilter(name: "CIColorControls") else { return input }
            controls.setValue(input, forKey: kCIInputImageKey)
            controls.setValue(0.08, forKey: kCIInputBrightnessKey)
            controls.setValue(1.45, forKey: kCIInputContrastKey)
            controls.setValue(0.0, forKey: kCIInputSaturationKey)
            return controls.outputImage ?? input
        }
    }

    private static func invertColors(_ image: UIImage) -> UIImage {
        applyFilters(to: image) { input in
            guard let invert = CIFilter(name: "CIColorInvert") else { return input }
            invert.setValue(input, forKey: kCIInputImageKey)
            guard let inverted = invert.outputImage else { return input }
            guard let controls = CIFilter(name: "CIColorControls") else { return inverted }
            controls.setValue(inverted, forKey: kCIInputImageKey)
            controls.setValue(1.25, forKey: kCIInputContrastKey)
            return controls.outputImage ?? inverted
        }
    }

    private static func applyFilters(
        to image: UIImage,
        _ block: (CIImage) -> CIImage
    ) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let input = CIImage(cgImage: cg)
        let output = block(input)
        guard let outCG = ciContext.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: outCG, scale: 1, orientation: .up)
    }

    private static func jpegData(_ image: UIImage, maxPixel: CGFloat) -> Data? {
        ImageProcessor.preparedJPEGData(
            from: image,
            maxPixel: maxPixel,
            quality: PerformanceConfig.groqVisionJPEGQuality
        )
    }
}
