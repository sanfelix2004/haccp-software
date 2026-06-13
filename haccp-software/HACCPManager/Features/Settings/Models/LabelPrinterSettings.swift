import Foundation

public struct LabelPrinterSettings: Codable {
    var defaultPrinterName: String = ""
    var savedPeripheralIdentifier: String = ""
    var savedPeripheralDisplayName: String = ""
    var labelSize: String = "50x30 mm"
    var printEngineRaw: String = ClabelPrintEngine.tsplText.rawValue
    var showProductName: Bool = true
    var showPrepDate: Bool = true
    var showExpiryDate: Bool = true
    var showLotNumber: Bool = true
    var showOperatorName: Bool = true
    var showAllergenWarning: Bool = true
    var showQRCode: Bool = true
    var qrRotationRaw: Int = LabelQRCodeRotation.r0.rawValue
    var qrCornerRaw: String = LabelQRCodeCorner.bottomRight.rawValue
    var qrCellSize: Int = 4 {
        didSet { qrCellSize = max(3, min(8, qrCellSize)) }
    }

    var printEngine: ClabelPrintEngine {
        get { ClabelPrintEngine(rawValue: printEngineRaw) ?? .auto }
        set { printEngineRaw = newValue.rawValue }
    }

    var qrRotation: LabelQRCodeRotation {
        get { LabelQRCodeRotation(rawValue: qrRotationRaw) ?? .r0 }
        set { qrRotationRaw = newValue.rawValue }
    }

    var qrCorner: LabelQRCodeCorner {
        get { LabelQRCodeCorner(rawValue: qrCornerRaw) ?? .topRight }
        set { qrCornerRaw = newValue.rawValue }
    }
}
