import AVFoundation
import UIKit

/// Normalizzazione immagine da fotocamera (orientamento, crop preview) — nessun OCR.
enum CameraCaptureImageProcessor {
    static func croppedToPreviewBounds(
        image: UIImage,
        previewLayer: AVCaptureVideoPreviewLayer,
        layerRect: CGRect? = nil
    ) -> UIImage {
        let upright = uprightUIImage(from: image)
        guard let cgImage = upright.cgImage else { return upright }

        let rectInLayer = layerRect ?? previewLayer.bounds
        guard rectInLayer.width > 0, rectInLayer.height > 0 else { return upright }

        let normalized = previewLayer.metadataOutputRectConverted(fromLayerRect: rectInLayer)
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: normalized.origin.x * width,
            y: (1 - normalized.origin.y - normalized.size.height) * height,
            width: normalized.size.width * width,
            height: normalized.size.height * height
        ).integral

        guard cropRect.width > 1, cropRect.height > 1,
              let cropped = cgImage.cropping(to: cropRect) else {
            return upright
        }
        return UIImage(cgImage: cropped, scale: upright.scale, orientation: .up)
    }

    static func uprightJPEGData(from image: UIImage, quality: CGFloat = 0.92) -> Data? {
        uprightUIImage(from: image).jpegData(compressionQuality: quality)
    }

    static func uprightUIImage(from image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        guard let cgImage = image.cgImage else { return image }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var transform = CGAffineTransform.identity
        var outputSize = CGSize(width: width, height: height)

        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height).rotated(by: .pi)
        case .left, .leftMirrored:
            outputSize = CGSize(width: height, height: width)
            transform = transform.translatedBy(x: width, y: 0).rotated(by: .pi / 2)
        case .right, .rightMirrored:
            outputSize = CGSize(width: height, height: width)
            transform = transform.translatedBy(x: 0, y: height).rotated(by: -.pi / 2)
        default:
            break
        }

        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }

        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: Int(outputSize.width),
                height: Int(outputSize.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return fallbackDrawNormalize(image)
        }

        context.concatenate(transform)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let normalized = context.makeImage() else { return fallbackDrawNormalize(image) }
        return UIImage(cgImage: normalized, scale: image.scale, orientation: .up)
    }

    static func uprightUIImage(from photo: AVCapturePhoto) -> UIImage? {
        guard let cgImage = photo.cgImageRepresentation() else { return nil }
        let orientation = uiOrientation(from: photo)
        return uprightUIImage(from: UIImage(cgImage: cgImage, scale: 1, orientation: orientation))
    }

    private static func uiOrientation(from photo: AVCapturePhoto) -> UIImage.Orientation {
        guard let value = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32,
              let exif = CGImagePropertyOrientation(rawValue: value) else {
            return .right
        }
        switch exif {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .right
        }
    }

    private static func fallbackDrawNormalize(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let size = image.size
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
