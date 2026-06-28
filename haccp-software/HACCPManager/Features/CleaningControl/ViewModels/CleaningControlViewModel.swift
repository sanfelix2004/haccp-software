import Foundation
import Combine

@MainActor
final class CleaningControlViewModel: ObservableObject {
    let service = CleaningControlService()
    @Published var selectedTab: Tab = .attivita
    @Published var noteDrafts: [UUID: String] = [:]
    @Published var actionDrafts: [UUID: String] = [:]

    enum Tab: String, CaseIterable, Identifiable {
        case attivita = "Attività"
        case storico = "Storico"

        var id: String { rawValue }
    }
}
