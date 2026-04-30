import Foundation
import Combine

@MainActor
final class SchedulingViewModel: ObservableObject {
    let service = SchedulingService()
}
