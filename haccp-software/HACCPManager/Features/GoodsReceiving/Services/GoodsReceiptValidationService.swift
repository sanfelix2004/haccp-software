import Foundation

struct GoodsReceiptValidationOutcome {
    let canSubmit: Bool
    let message: String?
    let requiresCorrectiveAction: Bool
    let temperatureOutOfRange: Bool
    /// Checklist NON OK o temperatura fuori range.
    let hasNonCompliance: Bool
}

struct GoodsReceiptValidationService {
    func hasNonCompliance(
        requirement: GoodsReceiptRequirement,
        checklistResults: [GoodsReceiptChecklistResult],
        temperatureValue: Double?
    ) -> Bool {
        let tempOut = temperatureOutOfRange(requirement: requirement, temperatureValue: temperatureValue)
        return checklistResults.contains(where: { $0.value == .notOk }) || tempOut
    }

    private func temperatureOutOfRange(requirement: GoodsReceiptRequirement, temperatureValue: Double?) -> Bool {
        guard let value = temperatureValue else { return false }
        if let min = requirement.defaultMinTemp, value < min { return true }
        if let max = requirement.defaultMaxTemp, value > max { return true }
        return false
    }

    func validate(
        requirement: GoodsReceiptRequirement,
        checklistResults: [GoodsReceiptChecklistResult],
        temperatureValue: Double?,
        lotNumber: String,
        hasExpiryDate: Bool,
        notes: String,
        correctiveAction: String,
        photoData: Data? = nil,
        enforcePhotoIfNonCompliant: Bool = false
    ) -> GoodsReceiptValidationOutcome {
        if requirement.requiresTemperature && temperatureValue == nil {
            return .init(canSubmit: false, message: "Inserisci la temperatura.", requiresCorrectiveAction: false, temperatureOutOfRange: false, hasNonCompliance: false)
        }
        if requirement.requiresLot && lotNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(canSubmit: false, message: "Inserisci il numero lotto.", requiresCorrectiveAction: false, temperatureOutOfRange: false, hasNonCompliance: false)
        }
        if requirement.requiresExpiryDate && hasExpiryDate == false {
            return .init(canSubmit: false, message: "Inserisci la data di scadenza.", requiresCorrectiveAction: false, temperatureOutOfRange: false, hasNonCompliance: false)
        }
        if requirement.requiresChecklist {
            let requiredItems = Set(requirement.checklistItems)
            let completedItems = Set(checklistResults.map(\.item))
            if requiredItems.isSubset(of: completedItems) == false {
                return .init(canSubmit: false, message: "Completa tutta la checklist HACCP.", requiresCorrectiveAction: false, temperatureOutOfRange: false, hasNonCompliance: false)
            }
        }

        let nonOkMissingNote = checklistResults.contains {
            $0.value == .notOk && ($0.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if nonOkMissingNote {
            return .init(canSubmit: false, message: "Per ogni voce NON OK serve una nota obbligatoria.", requiresCorrectiveAction: true, temperatureOutOfRange: false, hasNonCompliance: true)
        }

        let tempOut = temperatureOutOfRange(requirement: requirement, temperatureValue: temperatureValue)

        let hasNonCompliance = checklistResults.contains(where: { $0.value == .notOk }) || tempOut
        if hasNonCompliance {
            if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .init(canSubmit: false, message: "Inserisci il motivo della non conformità (note).", requiresCorrectiveAction: true, temperatureOutOfRange: tempOut, hasNonCompliance: true)
            }
            if correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .init(canSubmit: false, message: "Inserisci l'azione correttiva obbligatoria.", requiresCorrectiveAction: true, temperatureOutOfRange: tempOut, hasNonCompliance: true)
            }
        }

        if enforcePhotoIfNonCompliant && hasNonCompliance {
            let hasPhoto = (photoData?.isEmpty == false)
            if !hasPhoto {
                return .init(
                    canSubmit: false,
                    message: "Per una non conformità è obbligatorio allegare una foto.",
                    requiresCorrectiveAction: true,
                    temperatureOutOfRange: tempOut,
                    hasNonCompliance: true
                )
            }
        }

        return .init(
            canSubmit: true,
            message: tempOut ? "Temperatura fuori range: salvataggio consentito con nota." : nil,
            requiresCorrectiveAction: hasNonCompliance,
            temperatureOutOfRange: tempOut,
            hasNonCompliance: hasNonCompliance
        )
    }
}
