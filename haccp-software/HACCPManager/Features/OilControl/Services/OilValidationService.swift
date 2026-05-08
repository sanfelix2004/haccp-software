import Foundation

struct OilValidationResult {
    let status: OilStatus
    let message: String
}

struct OilValidationService {
    func validate(
        polarCompoundsValue: Double?,
        selectedStatus: OilStatus,
        settings: HACCPSettings
    ) -> OilValidationResult {
        guard let value = polarCompoundsValue else {
            return .init(status: selectedStatus, message: "Stato impostato manualmente.")
        }

        if value >= settings.oilPolarMaximumLimit {
            return .init(status: .daSostituire, message: "Valore sopra il limite massimo: sostituire l'olio.")
        }
        if value >= settings.oilPolarAttentionLimit {
            return .init(status: .daMonitorare, message: "Valore vicino alla soglia: monitorare il punto olio.")
        }
        return .init(status: .conforme, message: "Valore sotto soglia: olio conforme.")
    }
}
