import Foundation
import Combine

@MainActor
final class BlastChillingRecordViewModel: ObservableObject {
    @Published var startedAt = Date()
    @Published var endedAt = Date()
    @Published var initialTemperatureText = ""
    @Published var finalTemperatureText = ""
    @Published var activeTemperatureField: TemperatureField = .initial
    @Published var notes = ""
    @Published var correctiveAction = ""
    @Published var targetTemperature: Double = -18

    enum TemperatureField {
        case initial
        case final
    }

    var initialTemperature: Double? {
        Double(initialTemperatureText.replacingOccurrences(of: ",", with: "."))
    }

    var finalTemperature: Double? {
        Double(finalTemperatureText.replacingOccurrences(of: ",", with: "."))
    }

    var currentTemperatureText: String {
        switch activeTemperatureField {
        case .initial: return initialTemperatureText
        case .final: return finalTemperatureText
        }
    }

    func reset() {
        startedAt = Date()
        endedAt = Date()
        initialTemperatureText = ""
        finalTemperatureText = ""
        activeTemperatureField = .initial
        notes = ""
        correctiveAction = ""
        targetTemperature = -18
    }

    func tapKey(_ key: String) {
        var text = currentTemperatureText
        switch key {
        case "⌫":
            if !text.isEmpty { text.removeLast() }
        case "C":
            text = ""
        case "+/-":
            if text.hasPrefix("-") {
                text.removeFirst()
            } else if !text.isEmpty {
                text = "-" + text
            } else {
                text = "-"
            }
        case ".":
            if !text.contains(".") { text += "." }
        default:
            if text.count < 7 { text += key }
        }
        switch activeTemperatureField {
        case .initial: initialTemperatureText = text
        case .final: finalTemperatureText = text
        }
    }
}
