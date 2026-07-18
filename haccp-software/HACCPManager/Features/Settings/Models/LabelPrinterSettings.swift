import Foundation

public struct LabelPrinterSettings: Codable {
    var defaultPrinterName: String = ""
    var savedPeripheralIdentifier: String = ""
    var savedPeripheralDisplayName: String = ""
    /// Unico formato supportato: rotolo 50×30 mm.
    var labelSize: String = ClabelLabelSize.mm50x30.rawValue
    var printEngineRaw: String = ClabelPrintEngine.tsplText.rawValue
    var showProductName: Bool = true
    var showPrepDate: Bool = true
    var showExpiryDate: Bool = true
    var showLotNumber: Bool = true
    var showOperatorName: Bool = true
    var showAllergenWarning: Bool = true
    var showQRCode: Bool = true
    var qrRotationRaw: Int = LabelQRCodeRotation.r0.rawValue
    var qrCornerRaw: String = LabelQRCodeCorner.topRight.rawValue
    var qrCellSize: Int = 3 {
        didSet { qrCellSize = max(2, min(8, qrCellSize)) }
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
        get { LabelQRCodeCorner(rawValue: qrCornerRaw) ?? .bottomRight }
        set { qrCornerRaw = newValue.rawValue }
    }

    var clabelSize: ClabelLabelSize {
        get { .mm50x30 }
        set {
            labelSize = ClabelLabelSize.mm50x30.rawValue
            applyRecommendedLayout(for: .mm50x30)
        }
    }

    var labelSpec: ClabelLabelSpec {
        ClabelLabelSpec(size: .mm50x30)
    }

    var labelSizeDisplay: String {
        "50×30 mm · CLABEL S1"
    }

    mutating func applyRecommendedLayout(for size: ClabelLabelSize = .mm50x30) {
        labelSize = ClabelLabelSize.mm50x30.rawValue
        printEngine = .tsplText
        let profile = ClabelLabelSize.mm50x30.layoutProfile
        qrCellSize = profile.preferredQRCell
        qrCorner = .topRight
        qrRotation = .r0
        showOperatorName = true
        showAllergenWarning = true
        showProductName = true
        showPrepDate = true
        showExpiryDate = true
        showLotNumber = true
        showQRCode = true
        _ = size
    }
}
