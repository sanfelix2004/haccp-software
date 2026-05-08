import Foundation
import Combine

@MainActor
final class OilControlViewModel: ObservableObject {
    let service = OilControlService()
    @Published var selectedPoint: OilPoint?
    @Published var pointToEdit: OilPoint?
    @Published var showCheckSheet = false
    @Published var showPointEditor = false
    @Published var errorMessage: String?
    @Published var newPointName = ""
    @Published var historyStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var historyEndDate = Date()
    @Published var selectedHistoryPointId: UUID?
    @Published var selectedHistoryStatus: OilStatus?
    @Published var selectedHistoryOperator = "Tutti"
}
