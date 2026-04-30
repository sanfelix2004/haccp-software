import Foundation

struct GoodsReceiptValidationOutcome {
    let canSubmit: Bool
    let message: String?
    let requiresCorrectiveAction: Bool
    let temperatureOutOfRange: Bool
}

struct GoodsReceiptValidationService {
    func validate(
        requirement: GoodsReceiptRequirement,
        checklistResults: [GoodsReceiptChecklistResult],
        temperatureValue: Double?,
        lotNumber: String,
        hasExpiryDate: Bool,
        notes: String,
        correctiveAction: String
    ) -> GoodsReceiptValidationOutcome {
        if requirement.requiresTemperature && temperatureValue == nil {
            return .init(canSubmit: false, message: "Inserisci la temperatura.", requiresCorrectiveAction: false, temperatureOutOfRange: false)
        }
        if requirement.requiresLot && lotNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(canSubmit: false, message: "Inserisci il numero lotto.", requiresCorrectiveAction: false, temperatureOutOfRange: false)
        }
        if requirement.requiresExpiryDate && hasExpiryDate == false {
            return .init(canSubmit: false, message: "Inserisci la data di scadenza.", requiresCorrectiveAction: false, temperatureOutOfRange: false)
        }
        if requirement.requiresChecklist {
            let requiredItems = Set(requirement.checklistItems)
            let completedItems = Set(checklistResults.map(\.item))
            if requiredItems.isSubset(of: completedItems) == false {
                return .init(canSubmit: false, message: "Completa tutta la checklist HACCP.", requiresCorrectiveAction: false, temperatureOutOfRange: false)
            }
        }

        let nonOkMissingNote = checklistResults.contains {
            $0.value == .notOk && ($0.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if nonOkMissingNote {
            return .init(canSubmit: false, message: "Per ogni voce NON OK serve una nota obbligatoria.", requiresCorrectiveAction: true, temperatureOutOfRange: false)
        }

        let tempOut: Bool = {
            guard let value = temperatureValue else { return false }
            if let min = requirement.defaultMinTemp, value < min { return true }
            if let max = requirement.defaultMaxTemp, value > max { return true }
            return false
        }()

        let hasNonCompliance = checklistResults.contains(where: { $0.value == .notOk }) || tempOut
        if hasNonCompliance && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(canSubmit: false, message: "In caso di non conformita inserisci note o azione correttiva.", requiresCorrectiveAction: true, temperatureOutOfRange: tempOut)
        }

        return .init(canSubmit: true, message: tempOut ? "Temperatura fuori range: salvataggio consentito con nota." : nil, requiresCorrectiveAction: hasNonCompliance, temperatureOutOfRange: tempOut)
    }
}
