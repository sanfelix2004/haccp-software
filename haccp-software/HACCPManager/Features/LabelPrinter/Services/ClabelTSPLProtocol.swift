import Foundation

/// TSPL / TSPL2 — protocollo tipico stampanti CLABEL S1 (Bluetooth termica).
enum ClabelTSPLProtocol {

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
        let profile = spec.layout
        var data = Data()
        data.append(ascii("""
        SET TEAR ON\r\n\
        SET PEEL OFF\r\n\
        SET CUTTER OFF\r\n\
        CODEPAGE 1252\r\n\
        SIZE \(spec.widthMM) mm,\(spec.heightMM) mm\r\n\
        GAP \(spec.gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        CLS\r\n
        """))

        let payload = LabelQRCodeLayout.payload(for: label, restaurantName: restaurantName)
        let qrCell = settings.showQRCode
            ? LabelQRCodeLayout.clampedCellSize(settings.qrCellSize, payload: payload, settings: settings, corner: settings.qrCorner)
            : settings.qrCellSize
        let textInset = settings.showQRCode
            ? LabelQRCodeLayout.reservedColumnDots(cellSize: qrCell, payload: payload, settings: settings, corner: settings.qrCorner)
            : 0
        let textX = settings.qrCorner.reservesLeftColumn ? profile.tsplTextX + textInset : profile.tsplTextX

        var y = 12
        let step = max(18, profile.tsplDetailYStep - 2)
        for line in ProductionLabelPrintContent.printLines(for: label, settings: settings, restaurantName: restaurantName) {
            guard y < spec.heightDots - 20 else { break }
            let font = line.bold ? profile.tsplProductFont : profile.tsplDetailFont
            data.append(ascii("TEXT \(textX),\(y),\"\(font)\",0,1,1,\"\(tsplEscape(line.text))\"\r\n"))
            y += line.bold ? profile.tsplProductYStep : step
        }

        if settings.showQRCode {
            appendNativeQR(to: &data, payload: payload, settings: settings, cell: qrCell, spec: spec)
        }

        data.append(ascii("PRINT 1,1\r\n"))
        return data
    }

    static func buildTestJob(spec: ClabelLabelSpec = ClabelLabelDimensions.defaultSpec) -> Data {
        let qrX = spec.size == .mm40x30 ? 170 : 220
        return ascii(setupHeader + """
        SIZE \(spec.widthMM) mm,\(spec.heightMM) mm\r\n\
        GAP \(spec.gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        CLS\r\n\
        TEXT 12,70,\"3\",0,1,1,\"HACCP TEST\"\r\n\
        TEXT 12,120,\"2\",0,1,1,\"CLABEL S1 \(spec.widthMM)x\(spec.heightMM)\"\r\n\
        QRCODE \(qrX),36,L,\(spec.layout.preferredQRCell),A,0,\"HACCP%0AProdotto: Test%0ALotto: L001%0AProd: 10/07/26%0AScad: 12/07/26\"\r\n\
        PRINT 1,1\r\n
        """)
    }

    private static var setupHeader: String {
        """
        SET TEAR ON\r\n\
        SET PEEL OFF\r\n\
        SET CUTTER OFF\r\n\
        CODEPAGE 1252\r\n
        """
    }

    private static func appendNativeQR(
        to data: inout Data,
        payload: String,
        settings: LabelPrinterSettings,
        cell: Int,
        spec: ClabelLabelSpec
    ) {
        let qrSize = LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload)
        let (qx, qy) = settings.qrCorner.origin(
            labelWidth: spec.widthDots,
            labelHeight: spec.heightDots,
            qrBox: qrSize,
            margin: spec.layout.qrMarginDots
        )
        data.append(ascii(
            "QRCODE \(qx),\(qy),L,\(cell),A,\(settings.qrRotation.rawValue),\"\(tsplEscape(payload))\"\r\n"
        ))
    }

    private static func ascii(_ string: String) -> Data {
        Data(string.utf8)
    }

    private static func tsplEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
