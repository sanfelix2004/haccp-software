import Foundation

/// TSPL / TSPL2 — protocollo tipico stampanti CLABEL S1 (Bluetooth termica).
/// Layout fisso 50×30 mm: colonna testo sinistra + QR destra, con gap fisso.
enum ClabelTSPLProtocol {

    /// Larghezza massima colonna testo (dot) — oltre inizia il gap verso il QR.
    private static let textColumnEndX = 230
    private static let qrEdgeInset = 32
    private static let textQRGap = 24
    private static let qrTargetDots = 80
    private static let maxTextChars = 18

    static func buildBitmapJob(raster: Data, spec: ClabelLabelSpec) -> Data {
        var payload = Data()
        payload.append(ascii(setupHeader))
        payload.append(ascii("""
        SIZE \(spec.widthMM) mm,\(spec.heightMM) mm\r\n\
        GAP \(spec.gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        REFERENCE 0,0\r\n\
        DENSITY 10\r\n\
        SPEED 4\r\n\
        CLS\r\n\
        BITMAP 0,0,\(spec.widthBytes),\(spec.heightDots),0,
        """))
        payload.append(raster)
        payload.append(ascii("\r\nPRINT 1,1\r\n"))
        return payload
    }

    static func buildTextJob(
        label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        restaurantName: String? = nil
    ) -> Data {
        let spec = settings.labelSpec
        var data = Data()
        data.append(ascii("""
        SET TEAR ON\r\n\
        SET PEEL OFF\r\n\
        SET CUTTER OFF\r\n\
        CODEPAGE 1252\r\n\
        SIZE \(spec.widthMM) mm,\(spec.heightMM) mm\r\n\
        GAP \(spec.gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        REFERENCE 0,0\r\n\
        CLS\r\n
        """))

        let lines = ProductionLabelPrintContent.printLines(
            for: label,
            settings: settings,
            restaurantName: restaurantName
        )

        var y = 14
        let productStep = 34
        let detailStep = 26
        let textX = 14
        let maxY = min(spec.heightDots - 14, 220)

        for line in lines {
            guard y + 20 < maxY else { break }
            let font = line.bold ? "2" : "1"
            let clipped = ProductionLabelPrintContent.printerSafe(
                String(line.text.prefix(maxTextChars))
            )
            guard !clipped.isEmpty else { continue }
            data.append(cp1252Safe("TEXT \(textX),\(y),\"\(font)\",0,1,1,\"\(tsplEscape(clipped))\"\r\n"))
            y += line.bold ? productStep : detailStep
        }

        if settings.showQRCode {
            let payload = LabelQRCodeLayout.payload(for: label, restaurantName: restaurantName)
            let cell = bestQRCell(payload: payload, settings: settings, spec: spec)
            let qrSize = LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload, settings: settings)
            // Un po' più al centro: non a filo destro, ma ancora a destra del testo.
            let minX = textColumnEndX + textQRGap
            let maxX = spec.widthDots - qrSize - qrEdgeInset
            let qx = max(minX, maxX - 18)
            let qy = max(qrEdgeInset, (spec.heightDots - qrSize) / 2)
            data.append(cp1252Safe(
                "QRCODE \(qx),\(qy),M,\(cell),A,0,\"\(tsplEscape(payload))\"\r\n"
            ))
        }

        data.append(ascii("PRINT 1,1\r\n"))
        return data
    }

    static func buildTestJob(spec: ClabelLabelSpec = ClabelLabelDimensions.defaultSpec) -> Data {
        let qrX = max(textColumnEndX + textQRGap, spec.widthDots - 100 - qrEdgeInset)
        return ascii(setupHeader + """
        SIZE \(spec.widthMM) mm,\(spec.heightMM) mm\r\n\
        GAP \(spec.gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        REFERENCE 0,0\r\n\
        CLS\r\n\
        TEXT 14,20,\"2\",0,1,1,\"HACCP TEST\"\r\n\
        TEXT 14,60,\"1\",0,1,1,\"50x30 CLABEL\"\r\n\
        TEXT 14,90,\"1\",0,1,1,\"Scad 18/07\"\r\n\
        QRCODE \(qrX),40,M,4,A,0,\"HC2|TEST\"\r\n\
        PRINT 1,1\r\n
        """)
    }

    private static func bestQRCell(
        payload: String,
        settings: LabelPrinterSettings,
        spec: ClabelLabelSpec
    ) -> Int {
        let profile = spec.layout
        let upper = max(profile.preferredQRCell, settings.qrCellSize)
        let maxWidth = spec.widthDots - textColumnEndX - textQRGap - qrEdgeInset
        for cell in stride(from: min(5, upper), through: profile.minQRCell, by: -1) {
            let size = LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload, settings: settings)
            if size <= qrTargetDots, size <= spec.heightDots - 56, size <= maxWidth {
                return cell
            }
        }
        return profile.minQRCell
    }

    private static var setupHeader: String {
        """
        SET TEAR ON\r\n\
        SET PEEL OFF\r\n\
        SET CUTTER OFF\r\n\
        CODEPAGE 1252\r\n
        """
    }

    private static func ascii(_ string: String) -> Data {
        Data(string.utf8)
    }

    /// Solo byte ASCII 0x20–0x7E (+ CR/LF) — evita UTF-8 multibyte letti come ideogrammi.
    private static func cp1252Safe(_ string: String) -> Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(string.utf8.count)
        for scalar in string.unicodeScalars {
            let v = scalar.value
            if v == 0x0D || v == 0x0A || (v >= 0x20 && v <= 0x7E) {
                bytes.append(UInt8(v))
            }
        }
        return Data(bytes)
    }

    private static func tsplEscape(_ value: String) -> String {
        let cleaned = String(value.unicodeScalars.compactMap { scalar -> Character? in
            let v = scalar.value
            guard v == 0x0A || (v >= 0x20 && v <= 0x7E) else { return nil }
            return Character(scalar)
        })
        return cleaned
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "'")
    }
}
