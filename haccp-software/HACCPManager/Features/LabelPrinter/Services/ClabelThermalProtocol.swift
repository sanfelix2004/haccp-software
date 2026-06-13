import Foundation

/// Comandi termici compatibili con stampanti CLABEL / Chiteng (LuckPrinter SDK).
enum ClabelThermalProtocol {

    static let wakeBytes = Data(repeating: 0x00, count: 12)

    static let setGapPaper = Data([0x10, 0xFF, 0x84, 0x00])
    static let setDensityNormal = Data([0x10, 0xFF, 0x10, 0x00, 0x01])

    static let enableLujiang = Data([0x10, 0xFF, 0xF1, 0x03])
    static let stopLujiang = Data([0x10, 0xFF, 0xF1, 0x45])

    static let enableAiYin = Data([0x10, 0xFF, 0xFE, 0x01])
    static let stopAiYin = Data([0x10, 0xFF, 0xFE, 0x45])

    static let formFeedNextLabel = Data([0x1D, 0x0C])

    static func rasterImageHeader(widthBytes: Int, heightDots: Int) -> Data {
        var data = Data([0x1D, 0x76, 0x30, 0x00])
        let xL = UInt8(widthBytes & 0xFF)
        let xH = UInt8((widthBytes >> 8) & 0xFF)
        let yL = UInt8(heightDots & 0xFF)
        let yH = UInt8((heightDots >> 8) & 0xFF)
        data.append(contentsOf: [xL, xH, yL, yH])
        return data
    }

    static func buildPrintJob(raster: Data, widthBytes: Int, heightDots: Int, variant: PrintVariant = .lujiang) -> Data {
        let enable = variant == .lujiang ? enableLujiang : enableAiYin
        let stop = variant == .lujiang ? stopLujiang : stopAiYin
        var payload = Data()
        payload.append(setGapPaper)
        payload.append(setDensityNormal)
        payload.append(wakeBytes)
        payload.append(enable)
        payload.append(rasterImageHeader(widthBytes: widthBytes, heightDots: heightDots))
        payload.append(raster)
        payload.append(formFeedNextLabel)
        payload.append(stop)
        return payload
    }

    enum PrintVariant {
        case lujiang
        case aiYin
    }

    static func buildTestPattern(widthBytes: Int, heightDots: Int) -> Data {
        var rows = Data()
        for y in 0..<heightDots {
            var row = Data(repeating: 0x00, count: widthBytes)
            if y < 28 {
                row[0] = 0xFF
                row[widthBytes - 1] = 0xFF
            }
            if y == 40 || y == 120 || y == 200 {
                for i in 0..<widthBytes { row[i] = 0xAA }
            }
            rows.append(row)
        }
        return buildPrintJob(raster: rows, widthBytes: widthBytes, heightDots: heightDots)
    }
}
