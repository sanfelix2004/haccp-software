import Foundation

public struct LabelPrinterSettings: Codable {
    var defaultPrinterName: String = ""
    var savedPeripheralIdentifier: String = ""
    var savedPeripheralDisplayName: String = ""
    /// Valore enum `40x30` / `50x30` (compatibile con vecchio "50x30 mm").
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
    var qrCornerRaw: String = LabelQRCodeCorner.bottomRight.rawValue
    var qrCellSize: Int = 4 {
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
        get { ClabelLabelSize.parse(labelSize) ?? .mm50x30 }
        set {
            labelSize = newValue.rawValue
            applyRecommendedLayout(for: newValue)
        }
    }

    var labelSpec: ClabelLabelSpec {
        ClabelLabelSpec(size: clabelSize)
    }

    var labelSizeDisplay: String {
        "\(clabelSize.displayName) · CLABEL S1"
    }

    mutating func applyRecommendedLayout(for size: ClabelLabelSize) {
        let profile = size.layoutProfile
        if qrCellSize > profile.preferredQRCell {
            qrCellSize = profile.preferredQRCell
        }
        if size == .mm40x30 {
            qrCorner = .bottomRight
        }
    }
}
