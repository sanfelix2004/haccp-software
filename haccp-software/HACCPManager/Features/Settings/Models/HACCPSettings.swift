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
    var oilPolarAttentionLimit: Double = 20.0
    var oilPolarMaximumLimit: Double = 25.0
    var oilNonCompliancePhotoRequired: Bool = false

    var warningThresholdValue: Double {
        warningThreshold ?? 0.8
    }

    public init() {}

    enum CodingKeys: String, CodingKey {
        case fridgeMinTemp
        case fridgeMaxTemp
        case freezerMinTemp
        case freezerMaxTemp
        case blastChillerTemp
        case warningThreshold
        case tempCheckFrequency
        case productExpiryThreshold
        case storageDurationYears
        case labelFormat
        case oilPolarAttentionLimit
        case oilPolarMaximumLimit
        case oilNonCompliancePhotoRequired
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fridgeMinTemp = try container.decodeIfPresent(Double.self, forKey: .fridgeMinTemp) ?? fridgeMinTemp
        fridgeMaxTemp = try container.decodeIfPresent(Double.self, forKey: .fridgeMaxTemp) ?? fridgeMaxTemp
        freezerMinTemp = try container.decodeIfPresent(Double.self, forKey: .freezerMinTemp) ?? freezerMinTemp
        freezerMaxTemp = try container.decodeIfPresent(Double.self, forKey: .freezerMaxTemp) ?? freezerMaxTemp
        blastChillerTemp = try container.decodeIfPresent(Double.self, forKey: .blastChillerTemp) ?? blastChillerTemp
        warningThreshold = try container.decodeIfPresent(Double.self, forKey: .warningThreshold)
        tempCheckFrequency = try container.decodeIfPresent(Int.self, forKey: .tempCheckFrequency) ?? tempCheckFrequency
        productExpiryThreshold = try container.decodeIfPresent(Int.self, forKey: .productExpiryThreshold) ?? productExpiryThreshold
        storageDurationYears = try container.decodeIfPresent(Int.self, forKey: .storageDurationYears) ?? storageDurationYears
        labelFormat = try container.decodeIfPresent(String.self, forKey: .labelFormat) ?? labelFormat
        oilPolarAttentionLimit = try container.decodeIfPresent(Double.self, forKey: .oilPolarAttentionLimit) ?? oilPolarAttentionLimit
        oilPolarMaximumLimit = try container.decodeIfPresent(Double.self, forKey: .oilPolarMaximumLimit) ?? oilPolarMaximumLimit
        oilNonCompliancePhotoRequired = try container.decodeIfPresent(Bool.self, forKey: .oilNonCompliancePhotoRequired) ?? oilNonCompliancePhotoRequired
    }
}
