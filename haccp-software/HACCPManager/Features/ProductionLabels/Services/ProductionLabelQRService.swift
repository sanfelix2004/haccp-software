import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

private struct ProductionLabelQRPayloadV1: Codable {
    let v: Int
    let id: String
    let product: String
    let lot: String?
    let production: String
    let expiry: String
    let restaurantId: String
}

private struct ProductionLabelQRPayloadV2JSON: Codable {
    var v: Int = 2
    var id: String
    var p: String
    var l: String?
    var pd: String
    var ed: String
    var op: String?
    var su: String?
    var c: String?
    var a: String?
    var t: String?
    var s: String?
    var q: String?
    var st: String?
    var src: String?
    var n: String?
    var rn: String?

    func toScanData() -> ProductionLabelScanData? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return ProductionLabelScanData(
            id: uuid,
            productName: p,
            productionDate: parseISODay(pd),
            expiryDate: parseISODay(ed),
            lotCode: l,
            operatorName: op,
            supplier: su,
            category: c,
            allergens: a,
            temperatureNote: t,
            storageInstructions: s,
            quantityDisplay: q,
            productStatusLabel: st,
            sourceModuleLabel: src,
            notes: n,
            restaurantName: rn
        )
    }
}

enum ProductionLabelQRService {

    private static let compactPrefix = "HC1:"
    private static let richPrefix = "HC2"
    private static let pipeMarker = "HC2|"
    private static let jsonMarker = "HC2:"
    private static let scanProductMax = 18
    private static let scanFieldMax = 12

    /// Payload per stampa fisica — il più ricco possibile entro i limiti dell'adesivo.
    static func printPayload(for label: ProductionLabelRecord, restaurantName: String? = nil) -> String {
        buildScanPayload(
            for: label,
            restaurantName: restaurantName,
            settings: SettingsStorageService.shared.printer
        )
    }

    /// Payload salvato su record (allineato alla stampa).
    static func buildPayload(for label: ProductionLabelRecord, restaurantName: String? = nil) -> String {
        buildScanPayload(
            for: label,
            restaurantName: restaurantName,
            settings: SettingsStorageService.shared.printer
        )
    }

    private static func buildScanPayload(
        for label: ProductionLabelRecord,
        restaurantName: String? = nil,
        settings: LabelPrinterSettings
    ) -> String {
        let candidates =
            ProductionLabelPrintContent.humanReadableCandidates(for: label, restaurantName: restaurantName)
            + [
                buildFullPayload(for: label, restaurantName: restaurantName),
                buildEssentialPayload(for: label, restaurantName: restaurantName),
                compactScanPayload(for: label),
                compactMinimalPayload(for: label)
            ]
        let profile = settings.labelSpec.layout
        for cellSize in [profile.preferredQRCell, profile.minQRCell] {
            if let payload = candidates.first(where: {
                LabelQRCodeLayout.fitsOnLabel(payload: $0, cellSize: cellSize, settings: settings)
            }) {
                return payload
            }
        }
        return compactMinimalPayload(for: label)
    }

    private static func compactScanPayload(for label: ProductionLabelRecord) -> String {
        var fields = [
            "HC2",
            label.id.uuidString.uppercased(),
            scanClip(label.productName, max: scanProductMax),
            scanClip(label.lotCode ?? "", max: scanFieldMax),
            isoDay(label.productionDate),
            isoDay(label.expiryDate),
            scanClip(label.createdByNameSnapshot, max: scanFieldMax)
        ]
        let allergens = scanClip(label.allergens ?? "", max: scanFieldMax)
        if !allergens.isEmpty { fields.append(allergens) }
        return pipeEncode(fields)
    }

    private static func compactMinimalPayload(for label: ProductionLabelRecord) -> String {
        pipeEncode([
            "HC2",
            label.id.uuidString.uppercased(),
            scanClip(label.productName, max: scanProductMax),
            scanClip(label.lotCode ?? "", max: scanFieldMax),
            isoDay(label.productionDate),
            isoDay(label.expiryDate)
        ])
    }

    private static func scanClip(_ value: String, max: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(max))
    }

    private static func buildEssentialPayload(for label: ProductionLabelRecord, restaurantName: String? = nil) -> String {
        encodeFields(
            id: label.id.uuidString.uppercased(),
            product: label.productName,
            lot: label.lotCode ?? "",
            productionDay: label.productionDate,
            expiryDay: label.expiryDate,
            operatorName: label.createdByNameSnapshot,
            allergens: label.allergens ?? "",
            storage: label.storageInstructions ?? "",
            restaurant: restaurantName ?? "",
            status: label.productStatus.label,
            source: label.sourceModule.displayLabel
        )
    }

    private static func buildFullPayload(for label: ProductionLabelRecord, restaurantName: String?) -> String {
        encodeFields(
            id: label.id.uuidString.uppercased(),
            product: label.productName,
            lot: label.lotCode ?? "",
            productionDay: label.productionDate,
            expiryDay: label.expiryDate,
            operatorName: label.createdByNameSnapshot,
            supplier: label.supplier ?? "",
            category: label.category ?? "",
            allergens: label.allergens ?? "",
            temperature: label.temperatureNote ?? "",
            storage: label.storageInstructions ?? "",
            quantity: label.quantityDisplay ?? "",
            notes: label.notes ?? "",
            restaurant: restaurantName ?? "",
            status: label.productStatus.label,
            source: label.sourceModule.displayLabel
        )
    }

    private static func buildMinimalPayload(for label: ProductionLabelRecord) -> String {
        encodeFields(
            id: label.id.uuidString.uppercased(),
            product: label.productName,
            lot: label.lotCode ?? "",
            productionDay: label.productionDate,
            expiryDay: label.expiryDate
        )
    }

    private static func encodeFields(
        id: String,
        product: String,
        lot: String,
        productionDay: Date,
        expiryDay: Date,
        operatorName: String = "",
        supplier: String = "",
        category: String = "",
        allergens: String = "",
        temperature: String = "",
        storage: String = "",
        quantity: String = "",
        notes: String = "",
        restaurant: String = "",
        status: String = "",
        source: String = ""
    ) -> String {
        pipeEncode([
            "HC2",
            id,
            clip(product),
            clip(lot),
            isoDay(productionDay),
            isoDay(expiryDay),
            clip(operatorName),
            clip(supplier),
            clip(category),
            clip(allergens),
            clip(temperature),
            clip(storage),
            clip(quantity),
            clip(notes),
            clip(restaurant),
            clip(status),
            clip(source)
        ])
    }

    private static func pipeEncode(_ fields: [String]) -> String {
        fields.map(escapeField).joined(separator: "|")
    }

    private static func clip(_ value: String) -> String {
        scanClip(value, max: 28)
    }

    static func parseScanned(_ raw: String) -> ProductionLabelScanData? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let human = ProductionLabelPrintContent.parseHumanReadable(trimmed) {
            return human
        }

        if trimmed.hasPrefix(pipeMarker) {
            return parsePipePayload(trimmed)
        }

        if trimmed.uppercased().hasPrefix(jsonMarker.uppercased()) {
            let json = String(trimmed.dropFirst(jsonMarker.count))
            if let data = json.data(using: .utf8),
               let payload = try? JSONDecoder().decode(ProductionLabelQRPayloadV2JSON.self, from: data) {
                return payload.toScanData()
            }
        }

        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let payload = try? JSONDecoder().decode(ProductionLabelQRPayloadV2JSON.self, from: data) {
            return payload.toScanData()
        }

        if trimmed.uppercased().hasPrefix(compactPrefix.uppercased()) {
            let rawID = String(trimmed.dropFirst(compactPrefix.count))
            if let uuid = UUID(uuidString: rawID) {
                return idOnlyScanData(uuid)
            }
        }

        if let uuid = UUID(uuidString: trimmed) {
            return idOnlyScanData(uuid)
        }

        if let data = trimmed.data(using: .utf8),
           let legacy = try? JSONDecoder().decode(ProductionLabelQRPayloadV1.self, from: data),
           let uuid = UUID(uuidString: legacy.id) {
            return ProductionLabelScanData(
                id: uuid,
                productName: legacy.product,
                productionDate: parseISODay(legacy.production),
                expiryDate: parseISODay(legacy.expiry),
                lotCode: legacy.lot,
                operatorName: nil,
                supplier: nil,
                category: nil,
                allergens: nil,
                temperatureNote: nil,
                storageInstructions: nil,
                quantityDisplay: nil,
                productStatusLabel: nil,
                sourceModuleLabel: nil,
                notes: nil,
                restaurantName: nil
            )
        }

        return nil
    }

    static func moduleCount(for payload: String) -> Int {
        if let image = ciImage(from: payload) {
            return max(21, Int(image.extent.width.rounded()))
        }
        return estimatedModuleCount(for: payload)
    }

    /// Stima moduli se CoreImage non disponibile.
    static func estimatedModuleCount(for payload: String) -> Int {
        let bytes = payload.utf8.count
        let version: Int
        switch bytes {
        case 0..<14: version = 1
        case 14..<26: version = 2
        case 26..<42: version = 3
        case 42..<62: version = 4
        case 62..<84: version = 5
        case 84..<106: version = 6
        case 106..<124: version = 7
        case 124..<152: version = 8
        case 152..<180: version = 9
        case 180..<213: version = 10
        case 213..<251: version = 11
        default: version = 12
        }
        return 21 + 4 * (version - 1)
    }

    static func cgImage(from string: String, dimension: CGFloat) -> CGImage? {
        guard dimension >= 1, dimension.isFinite else { return nil }
        guard let image = ciImage(from: string) else { return nil }
        let moduleWidth = max(image.extent.width, 1)
        let scale = dimension / moduleWidth
        guard scale > 0, scale.isFinite else { return nil }
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = scaled.extent.integral
        guard extent.width >= 1, extent.height >= 1 else { return nil }
        return sharedCIContext.createCGImage(scaled, from: extent)
    }

    static func image(from string: String, dimension: CGFloat = 120) -> UIImage? {
        guard let cgImage = cgImage(from: string, dimension: dimension) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Ruota bitmap QR per anteprima/stampa (evita rotationEffect SwiftUI che causa layout 0×N).
    static func image(
        from string: String,
        dimension: CGFloat,
        rotation: LabelQRCodeRotation
    ) -> UIImage? {
        guard let base = image(from: string, dimension: dimension) else { return nil }
        guard rotation != .r0 else { return base }
        return rotateImage(base, rotation: rotation)
    }

    private static func rotateImage(_ image: UIImage, rotation: LabelQRCodeRotation) -> UIImage? {
        let radians = rotation.radians
        let swap = rotation == .r90 || rotation == .r270
        let canvas = swap
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size
        guard canvas.width >= 1, canvas.height >= 1 else { return image }

        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: canvas.width / 2, y: canvas.height / 2)
            ctx.cgContext.rotate(by: radians)
            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }

    private static let sharedCIContext = CIContext()

    static func resolveLabelID(from scanned: String) -> UUID? {
        parseScanned(scanned)?.id
    }

    // MARK: - Pipe codec

    private static func parsePipePayload(_ raw: String) -> ProductionLabelScanData? {
        let body = String(raw.dropFirst(pipeMarker.count))
        let fields = splitEscapedFields(body)
        guard fields.count >= 5,
              let uuid = UUID(uuidString: fields[0]) else { return nil }

        func field(_ index: Int) -> String? {
            guard index < fields.count else { return nil }
            let value = unescapeField(fields[index])
            return value.isEmpty ? nil : value
        }

        return ProductionLabelScanData(
            id: uuid,
            productName: field(1) ?? "",
            productionDate: field(3).flatMap(parseISODay),
            expiryDate: field(4).flatMap(parseISODay),
            lotCode: field(2),
            operatorName: field(5),
            supplier: field(6),
            category: field(7),
            allergens: field(8),
            temperatureNote: field(9),
            storageInstructions: field(10),
            quantityDisplay: field(11),
            productStatusLabel: field(14),
            sourceModuleLabel: field(15),
            notes: field(12),
            restaurantName: field(13)
        )
    }

    private static func splitEscapedFields(_ body: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var index = body.startIndex

        while index < body.endIndex {
            if body[index] == "|" {
                fields.append(current)
                current = ""
                index = body.index(after: index)
                continue
            }
            if body[index] == "%" {
                let codeStart = body.index(after: index)
                guard let codeEnd = body.index(codeStart, offsetBy: 2, limitedBy: body.endIndex) else {
                    current.append(body[index])
                    index = body.index(after: index)
                    continue
                }
                let code = String(body[codeStart..<codeEnd])
                if code == "7C" {
                    current.append("|")
                    index = codeEnd
                    continue
                }
                if code == "25" {
                    current.append("%")
                    index = codeEnd
                    continue
                }
            }
            current.append(body[index])
            index = body.index(after: index)
        }
        fields.append(current)
        return fields
    }

    private static func escapeField(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "|", with: "%7C")
    }

    private static func unescapeField(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%7C", with: "|")
            .replacingOccurrences(of: "%25", with: "%")
    }

    private static func isoDay(_ date: Date) -> String {
        let normalized = HACCPDateNormalizer.startOfLocalDay(date)
        let parts = HACCPDateNormalizer.calendar.dateComponents([.year, .month, .day], from: normalized)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func ciImage(from string: String) -> CIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "L"
        return filter.outputImage
    }

    private static func idOnlyScanData(_ uuid: UUID) -> ProductionLabelScanData {
        ProductionLabelScanData(
            id: uuid,
            productName: "",
            productionDate: nil,
            expiryDate: nil,
            lotCode: nil,
            operatorName: nil,
            supplier: nil,
            category: nil,
            allergens: nil,
            temperatureNote: nil,
            storageInstructions: nil,
            quantityDisplay: nil,
            productStatusLabel: nil,
            sourceModuleLabel: nil,
            notes: nil,
            restaurantName: nil
        )
    }
}

private func parseISODay(_ value: String) -> Date? {
    HACCPDateNormalizer.dateFromDayString(value)
}
