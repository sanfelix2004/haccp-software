import Foundation
import Combine

@MainActor
final class ChecklistRunViewModel: ObservableObject {
    @Published var localNotes: [UUID: String] = [:]
    @Published var completionError: String?

    func resultBindingValue(for result: ChecklistItemResult) -> ChecklistItemResultValue {
        result.result
    }
}
