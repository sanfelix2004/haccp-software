import Foundation
import Combine

@MainActor
final class CleaningControlViewModel: ObservableObject {
    let service = CleaningControlService()
    @Published var selectedTab: Tab = .oggi
    @Published var noteDrafts: [UUID: String] = [:]
    @Published var actionDrafts: [UUID: String] = [:]

    enum Tab: String, CaseIterable, Identifiable {
        case oggi = "Da fare oggi"
        case ritardo = "In ritardo"
        case completate = "Completate"
        case storico = "Storico"

        var id: String { rawValue }
    }
}
