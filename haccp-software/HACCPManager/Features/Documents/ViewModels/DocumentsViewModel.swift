import Foundation
import Combine

@MainActor
final class DocumentsViewModel: ObservableObject {
    let service = DocumentsService()
    @Published var selectedFolderId: UUID?
    @Published var selectedPeriodFilter: PeriodFilter = .all

    enum PeriodFilter: String, CaseIterable, Identifiable {
        case all = "Tutti"
        case giornaliero = "Giornalieri"
        case settimanale = "Settimanali"
        case mensile = "Mensili"
        case annuale = "Annuali"
        var id: String { rawValue }
    }
}
