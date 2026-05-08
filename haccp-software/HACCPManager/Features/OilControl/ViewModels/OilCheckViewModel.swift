import Foundation
import Combine

@MainActor
final class OilCheckViewModel: ObservableObject {
    @Published var checkedAt = Date()
    @Published var selectedStatus: OilStatus = .conforme
    @Published var polarCompoundsText = ""
    @Published var temperatureText = ""
    @Published var actionTaken: OilAction = .nessunaAzione
    @Published var notes = ""
    @Published var photoData: Data?
    @Published var validationMessage = ""

    private let validationService = OilValidationService()

    func polarCompoundsValue() -> Double? {
        parseOptionalDouble(polarCompoundsText)
    }

    func temperatureValue() -> Double? {
        parseOptionalDouble(temperatureText)
    }

    var hasInvalidNumericInput: Bool {
        hasInvalidDouble(polarCompoundsText) || hasInvalidDouble(temperatureText)
    }

    func updateValidation(settings: HACCPSettings) {
        let result = validationService.validate(
            polarCompoundsValue: polarCompoundsValue(),
            selectedStatus: selectedStatus,
            settings: settings
        )
        selectedStatus = result.status
        validationMessage = result.message
    }

    private func parseOptionalDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private func hasInvalidDouble(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return Double(trimmed.replacingOccurrences(of: ",", with: ".")) == nil
    }
}
