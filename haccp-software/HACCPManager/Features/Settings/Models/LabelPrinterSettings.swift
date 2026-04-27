import Foundation

public struct LabelPrinterSettings: Codable {
    var defaultPrinterName: String = ""
    var labelSize: String = "50x30 mm"
    var showProductName: Bool = true
    var showPrepDate: Bool = true
    var showExpiryDate: Bool = true
    var showLotNumber: Bool = true
    var showOperatorName: Bool = true
    var showAllergenWarning: Bool = true
}
