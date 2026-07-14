import Foundation
import Combine

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: AnalyticsPeriod = .sevenDays
    @Published var selectedDeviceId: UUID?
}
