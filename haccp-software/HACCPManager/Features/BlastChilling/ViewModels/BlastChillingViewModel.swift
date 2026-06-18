import Foundation
import Combine

@MainActor
final class BlastChillingViewModel: ObservableObject {
    let service = BlastChillingService()
    @Published var showRecordSheet = false
    @Published var errorMessage: String?
    @Published var selectedHistoryCategoryId: UUID?
    @Published var selectedHistoryStatus: BlastChillingStatus?
    @Published var selectedHistoryOperator: String = "Tutti"
    @Published var historyStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @Published var historyEndDate: Date = Date()
}
