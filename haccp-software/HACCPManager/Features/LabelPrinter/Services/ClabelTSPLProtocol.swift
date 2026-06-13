import Foundation

/// TSPL / TSPL2 — protocollo tipico stampanti CLABEL desktop (S1, CT320, ecc.).
enum ClabelTSPLProtocol {

    static let widthMM = 50
    static let heightMM = 30
    static let gapMM = 3

    private static var setupHeader: String {
        """
        SET TEAR ON\r\n\
        SET PEEL OFF\r\n\
        SET CUTTER OFF\r\n\
        CODEPAGE 1252\r\n
        """
    }

    static func buildBitmapJob(raster: Data, widthBytes: Int, heightDots: Int) -> Data {
        var payload = Data()
        payload.append(ascii(setupHeader))
        payload.append(ascii("""
        SIZE \(widthMM) mm,\(heightMM) mm\r\n\
        GAP \(gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        REFERENCE 0,0\r\n\
        DENSITY 10\r\n\
        SPEED 4\r\n\
        CLS\r\n\
        BITMAP 0,0,\(widthBytes),\(heightDots),0,
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
        var data = Data()
        data.append(ascii("""
        SET TEAR ON\r\n\
        SET PEEL OFF\r\n\
        SET CUTTER OFF\r\n\
        CODEPAGE 1252\r\n\
        SIZE \(widthMM) mm,\(heightMM) mm\r\n\
        GAP \(gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        CLS\r\n
        """))

        let payload = LabelQRCodeLayout.payload(for: label, restaurantName: restaurantName)
        let qrCell = settings.showQRCode
            ? LabelQRCodeLayout.clampedCellSize(settings.qrCellSize, payload: payload, corner: settings.qrCorner)
            : settings.qrCellSize
        let textInset = settings.showQRCode
            ? LabelQRCodeLayout.reservedColumnDots(cellSize: qrCell, payload: payload, corner: settings.qrCorner)
            : 0
        let textX = settings.qrCorner.reservesLeftColumn ? 12 + textInset : 12

        var y = 16
        if settings.showProductName {
            data.append(ascii("TEXT \(textX),\(y),\"3\",0,1,1,\"\(tsplEscape(label.productName.uppercased()))\"\r\n"))
            y += 36
        }
        if settings.showLotNumber, let lot = label.lotCode, !lot.isEmpty {
            data.append(ascii("TEXT \(textX),\(y),\"2\",0,1,1,\"Lotto \(tsplEscape(lot))\"\r\n"))
            y += 28
        }
        if settings.showPrepDate {
            let d = label.productionDate.formatted(date: .abbreviated, time: .omitted)
            data.append(ascii("TEXT \(textX),\(y),\"1\",0,1,1,\"Prod. \(tsplEscape(d))\"\r\n"))
            y += 24
        }
        if settings.showExpiryDate {
            let d = label.expiryDate.formatted(date: .abbreviated, time: .omitted)
            data.append(ascii("TEXT \(textX),\(y),\"1\",0,1,1,\"Scad. \(tsplEscape(d))\"\r\n"))
            y += 24
        }
        if settings.showOperatorName {
            data.append(ascii("TEXT \(textX),\(y),\"1\",0,1,1,\"Op. \(tsplEscape(label.createdByNameSnapshot))\"\r\n"))
            y += 24
        }
        if settings.showAllergenWarning, !label.allergenList.isEmpty {
            let text = label.allergenList.joined(separator: ", ")
            data.append(ascii("TEXT \(textX),\(y),\"1\",0,1,1,\"All: \(tsplEscape(text))\"\r\n"))
        }

        if settings.showQRCode {
            appendNativeQR(
                to: &data,
                payload: payload,
                settings: settings,
                cell: qrCell
            )
        }

        data.append(ascii("PRINT 1,1\r\n"))
        return data
    }

    static func buildTestJob() -> Data {
        ascii(setupHeader + """
        SIZE \(widthMM) mm,\(heightMM) mm\r\n\
        GAP \(gapMM) mm,0 mm\r\n\
        DIRECTION 1,0\r\n\
        CLS\r\n\
        TEXT 40,80,\"4\",0,1,1,\"HACCP TEST\"\r\n\
        TEXT 20,140,\"2\",0,1,1,\"CLABEL 50x30\"\r\n\
        QRCODE 220,40,L,4,A,0,\"HC2|TEST|Prodotto|L001|2026-06-13|2026-06-15\"\r\n\
        PRINT 1,1\r\n
        """)
    }

    /// QRCODE nativo TSPL — stampa moduli nitidi, senza bordo nero del bitmap.
    private static func appendNativeQR(
        to data: inout Data,
        payload: String,
        settings: LabelPrinterSettings,
        cell: Int
    ) {
        let qrSize = LabelQRCodeLayout.printSizeDots(cellSize: cell, payload: payload)
        let (qx, qy) = settings.qrCorner.origin(
            labelWidth: ClabelLabelDimensions.widthDots,
            labelHeight: ClabelLabelDimensions.heightDots,
            qrBox: qrSize
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
