import Foundation

struct ChecklistValidationService {
    func canCompleteRun(
        run: ChecklistRun,
        itemTemplates: [ChecklistItemTemplate],
        itemResults: [ChecklistItemResult]
    ) -> (canComplete: Bool, failedRequiredItems: [ChecklistItemResult], message: String?) {
        let templateById = Dictionary(uniqueKeysWithValues: itemTemplates.map { ($0.id, $0) })

        var missingRequired = 0
        var failedRequired: [ChecklistItemResult] = []

        for result in itemResults {
            guard let template = templateById[result.itemTemplateId] else { continue }
            if template.isRequired && result.result == .pending {
                missingRequired += 1
            }
            if result.result == .fail {
                if template.requiresNoteIfFailed && (result.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false) {
                    return (false, failedRequired, "Aggiungi una nota per gli item falliti obbligatori.")
                }
                failedRequired.append(result)
            }
        }

        if missingRequired > 0 {
            return (false, failedRequired, "Compila tutti gli item obbligatori prima di completare.")
        }

        return (true, failedRequired, nil)
    }
}
