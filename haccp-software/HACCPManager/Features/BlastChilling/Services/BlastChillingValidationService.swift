import Foundation

struct BlastChillingValidationOutcome {
    let canSubmit: Bool
    let status: BlastChillingStatus
    let message: String?
    let requiresCorrectiveAction: Bool
}

struct BlastChillingValidationService {
    func validateStart(
        startedAt: Date,
        initialTemperature: Double?
    ) -> BlastChillingValidationOutcome {
        guard initialTemperature != nil else {
            return .init(canSubmit: false, status: .inCorso, message: "Inserisci la temperatura iniziale.", requiresCorrectiveAction: false)
        }
        guard startedAt <= Date().addingTimeInterval(60) else {
            return .init(canSubmit: false, status: .inCorso, message: "La data/ora inizio non può essere nel futuro.", requiresCorrectiveAction: false)
        }
        return .init(canSubmit: true, status: .inCorso, message: nil, requiresCorrectiveAction: false)
    }

    func validateCompletion(
        startedAt: Date,
        endedAt: Date,
        finalTemperature: Double?,
        targetTemperature: Double,
        notes: String?,
        correctiveAction: String?
    ) -> BlastChillingValidationOutcome {
        guard let finalTemperature else {
            return .init(canSubmit: false, status: .inCorso, message: "Inserisci la temperatura finale.", requiresCorrectiveAction: false)
        }
        guard endedAt >= startedAt else {
            return .init(canSubmit: false, status: .inCorso, message: "La data/ora fine non può precedere l'inizio.", requiresCorrectiveAction: false)
        }

        let isConforme = finalTemperature <= targetTemperature
        guard isConforme else {
            let note = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let action = (correctiveAction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if note.isEmpty {
                return .init(canSubmit: false, status: .nonConforme, message: "Inserisci una nota per abbattimento non conforme.", requiresCorrectiveAction: true)
            }
            if action.isEmpty {
                return .init(canSubmit: false, status: .nonConforme, message: "Inserisci l'azione correttiva obbligatoria.", requiresCorrectiveAction: true)
            }
            return .init(canSubmit: true, status: .nonConforme, message: nil, requiresCorrectiveAction: true)
        }

        return .init(canSubmit: true, status: .conforme, message: nil, requiresCorrectiveAction: false)
    }

    func validate(
        startedAt: Date,
        endedAt: Date,
        initialTemperature: Double?,
        finalTemperature: Double?,
        targetTemperature: Double,
        notes: String?,
        correctiveAction: String?
    ) -> BlastChillingValidationOutcome {
        guard initialTemperature != nil else {
            return .init(canSubmit: false, status: .inCorso, message: "Inserisci la temperatura iniziale.", requiresCorrectiveAction: false)
        }
        return validateCompletion(
            startedAt: startedAt,
            endedAt: endedAt,
            finalTemperature: finalTemperature,
            targetTemperature: targetTemperature,
            notes: notes,
            correctiveAction: correctiveAction
        )
    }
}
