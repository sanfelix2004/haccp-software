import Foundation

struct TemperatureValidationResult {
    let status: TemperatureStatus
    let severity: TemperatureSeverity
    let message: String
    let minAllowed: Double
    let maxAllowed: Double
}

struct TemperatureValidationService {
    func validate(value: Double, device: TemperatureDevice, settings: HACCPSettings) -> TemperatureValidationResult {
        let range = allowedRange(for: device, settings: settings)
        let warningThreshold = settings.warningThresholdValue

        if value < range.min - warningThreshold || value > range.max + warningThreshold {
            return TemperatureValidationResult(
                status: .critical,
                severity: .critical,
                message: "Temperatura critica: fuori range operativo.",
                minAllowed: range.min,
                maxAllowed: range.max
            )
        }

        if value < range.min || value > range.max {
            return TemperatureValidationResult(
                status: .outOfRange,
                severity: .high,
                message: "Temperatura fuori range HACCP.",
                minAllowed: range.min,
                maxAllowed: range.max
            )
        }

        let lowWarn = range.min + warningThreshold
        let highWarn = range.max - warningThreshold
        if value <= lowWarn || value >= highWarn {
            return TemperatureValidationResult(
                status: .warning,
                severity: .warning,
                message: "Temperatura vicina ai limiti.",
                minAllowed: range.min,
                maxAllowed: range.max
            )
        }

        return TemperatureValidationResult(
            status: .ok,
            severity: .info,
            message: "Temperatura conforme.",
            minAllowed: range.min,
            maxAllowed: range.max
        )
    }

    func allowedRange(for device: TemperatureDevice, settings: HACCPSettings) -> (min: Double, max: Double) {
        if let customMin = device.customMinTemp, let customMax = device.customMaxTemp {
            return (customMin, customMax)
        }

        switch device.type {
        case .fridge:
            return (settings.fridgeMinTemp, settings.fridgeMaxTemp)
        case .freezer:
            return (settings.freezerMinTemp, settings.freezerMaxTemp)
        case .blastChiller:
            return (settings.blastChillerTemp - 1, settings.blastChillerTemp + 1)
        case .hotHolding:
            return (60, 80)
        case .ambient:
            return (10, 35)
        }
    }
}
