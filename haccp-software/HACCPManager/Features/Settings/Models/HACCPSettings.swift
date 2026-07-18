import Foundation

public struct HACCPSettings: Codable {
    var fridgeMinTemp: Double = 0.0
    var fridgeMaxTemp: Double = 5.0
    var freezerMinTemp: Double = -24.0
    var freezerMaxTemp: Double = -18.0
    var blastChillerTemp: Double = 3.0
    var warningThreshold: Double?
    var geminiApiKey: String?
    /// Chiave API Groq per lettura etichette (Llama 4 Maverick vision).
    var groqApiKey: String?
    
    var tempCheckFrequency: Int = 4 // hours
    var productExpiryThreshold: Int = 3 // days
    /// Obsoleto: il codice lotto in tracciabilità è sempre opzionale (conta la foto).
    /// Mantenuto solo per compatibilità con impostazioni già salvate.
    var lotEntryMandatory: Bool = false

    var storageDurationYears: Int = 5
    var labelFormat: String = "Standard 50x30"
    var oilPolarAttentionLimit: Double = 20.0
    var oilPolarMaximumLimit: Double = 25.0
    var oilNonCompliancePhotoRequired: Bool = false

    var defrostFridgeRecommendedHours: Int = PerformanceConfig.defrostFridgeRecommendedHours
    var defrostControlledTempRecommendedHours: Int = PerformanceConfig.defrostControlledTempRecommendedHours
    var defrostColdWaterRecommendedHours: Int = PerformanceConfig.defrostColdWaterRecommendedHours
    var defrostMicrowaveRecommendedHours: Int = PerformanceConfig.defrostMicrowaveRecommendedHours
    var defrostOtherRecommendedHours: Int = PerformanceConfig.defrostOtherRecommendedHours

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
        case geminiApiKey
        case groqApiKey
        case tempCheckFrequency
        case productExpiryThreshold
        case lotEntryMandatory
        case storageDurationYears
        case labelFormat
        case oilPolarAttentionLimit
        case oilPolarMaximumLimit
        case oilNonCompliancePhotoRequired
        case defrostFridgeRecommendedHours
        case defrostControlledTempRecommendedHours
        case defrostColdWaterRecommendedHours
        case defrostMicrowaveRecommendedHours
        case defrostOtherRecommendedHours
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fridgeMinTemp = try container.decodeIfPresent(Double.self, forKey: .fridgeMinTemp) ?? fridgeMinTemp
        fridgeMaxTemp = try container.decodeIfPresent(Double.self, forKey: .fridgeMaxTemp) ?? fridgeMaxTemp
        freezerMinTemp = try container.decodeIfPresent(Double.self, forKey: .freezerMinTemp) ?? freezerMinTemp
        freezerMaxTemp = try container.decodeIfPresent(Double.self, forKey: .freezerMaxTemp) ?? freezerMaxTemp
        blastChillerTemp = try container.decodeIfPresent(Double.self, forKey: .blastChillerTemp) ?? blastChillerTemp
        warningThreshold = try container.decodeIfPresent(Double.self, forKey: .warningThreshold)
        geminiApiKey = try container.decodeIfPresent(String.self, forKey: .geminiApiKey)
        groqApiKey = try container.decodeIfPresent(String.self, forKey: .groqApiKey)
        tempCheckFrequency = try container.decodeIfPresent(Int.self, forKey: .tempCheckFrequency) ?? tempCheckFrequency
        productExpiryThreshold = try container.decodeIfPresent(Int.self, forKey: .productExpiryThreshold) ?? productExpiryThreshold
        lotEntryMandatory = false
        storageDurationYears = try container.decodeIfPresent(Int.self, forKey: .storageDurationYears) ?? storageDurationYears
        labelFormat = try container.decodeIfPresent(String.self, forKey: .labelFormat) ?? labelFormat
        oilPolarAttentionLimit = try container.decodeIfPresent(Double.self, forKey: .oilPolarAttentionLimit) ?? oilPolarAttentionLimit
        oilPolarMaximumLimit = try container.decodeIfPresent(Double.self, forKey: .oilPolarMaximumLimit) ?? oilPolarMaximumLimit
        oilNonCompliancePhotoRequired = try container.decodeIfPresent(Bool.self, forKey: .oilNonCompliancePhotoRequired) ?? oilNonCompliancePhotoRequired
        defrostFridgeRecommendedHours = try container.decodeIfPresent(Int.self, forKey: .defrostFridgeRecommendedHours) ?? defrostFridgeRecommendedHours
        defrostControlledTempRecommendedHours = try container.decodeIfPresent(Int.self, forKey: .defrostControlledTempRecommendedHours) ?? defrostControlledTempRecommendedHours
        defrostColdWaterRecommendedHours = try container.decodeIfPresent(Int.self, forKey: .defrostColdWaterRecommendedHours) ?? defrostColdWaterRecommendedHours
        defrostMicrowaveRecommendedHours = try container.decodeIfPresent(Int.self, forKey: .defrostMicrowaveRecommendedHours) ?? defrostMicrowaveRecommendedHours
        defrostOtherRecommendedHours = try container.decodeIfPresent(Int.self, forKey: .defrostOtherRecommendedHours) ?? defrostOtherRecommendedHours
    }
}

extension HACCPSettings {
    func recommendedDefrostHours(for method: DefrostMethod) -> Int {
        switch method {
        case .frigorifero: return defrostFridgeRecommendedHours
        case .temperaturaControllata: return defrostControlledTempRecommendedHours
        case .acquaFredda: return defrostColdWaterRecommendedHours
        case .fornoMicroonde: return defrostMicrowaveRecommendedHours
        case .altro: return defrostOtherRecommendedHours
        }
    }
}
