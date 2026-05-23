//
//  ProductionLabelQRService.swift
//  Payload QR + rendering CoreImage.
//

import CoreImage.CIFilterBuiltins
import UIKit

struct ProductionLabelQRPayload: Codable {
    let v: Int
    let id: String
    let product: String
    let lot: String?
    let production: String
    let expiry: String
    let restaurantId: String
}

enum ProductionLabelQRService {

    static func buildPayload(for label: ProductionLabelRecord) -> String {
        let payload = ProductionLabelQRPayload(
            v: 1,
            id: label.id.uuidString,
            product: label.productName,
            lot: label.lotCode,
            production: ISO8601DateFormatter().string(from: label.productionDate),
            expiry: ISO8601DateFormatter().string(from: label.expiryDate),
            restaurantId: label.restaurantId.uuidString
        )
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        return String(data: data, encoding: .utf8) ?? label.id.uuidString
    }

    static func image(from string: String, dimension: CGFloat = 120) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = dimension / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
