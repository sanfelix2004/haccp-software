import UIKit

/// Compressione immagini per PDF (dati originali DB non modificati).
enum HACCPPDFImageCompression {
    private static let maxDimension: CGFloat = 720
    private static let jpegQuality: CGFloat = 0.48

    static func compressedJPEGData(from data: Data?) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let resized = downscale(image: image, maxSide: maxDimension)
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    private static func downscale(image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrent = max(size.width, size.height)
        guard maxCurrent > maxSide else { return image }
        let scale = maxSide / maxCurrent
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
