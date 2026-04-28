import Foundation

public struct HACCPSettings: Codable {
    var fridgeMinTemp: Double = 0.0
    var fridgeMaxTemp: Double = 5.0
    var freezerMinTemp: Double = -24.0
    var freezerMaxTemp: Double = -18.0
    var blastChillerTemp: Double = 3.0
    var warningThreshold: Double?
    
    var tempCheckFrequency: Int = 4 // hours
    var productExpiryThreshold: Int = 3 // days
    
    var storageDurationYears: Int = 5
    var labelFormat: String = "Standard 50x30"

    var warningThresholdValue: Double {
        warningThreshold ?? 0.8
    }
}
