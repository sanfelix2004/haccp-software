import Foundation
import Combine

@MainActor
final class ChecklistTemplateViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var category: ChecklistCategory = .opening
    @Published var frequency: ChecklistFrequency = .daily
    @Published var scheduledHour: Int = 9
    @Published var scheduledMinute: Int = 0
    @Published var items: [ChecklistItemTemplateDraft] = []
    @Published var validationError: String?

    func addItem() {
        items.append(
            .init(
                title: "",
                description: "",
                type: .passFail,
                isRequired: true,
                requiresNoteIfFailed: true
            )
        )
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func validateBeforeSave() -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Inserisci un titolo checklist."
            return false
        }
        guard !items.isEmpty else {
            validationError = "Aggiungi almeno un item."
            return false
        }
        guard items.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            validationError = "Ogni item deve avere un titolo."
            return false
        }
        validationError = nil
        return true
    }
}
