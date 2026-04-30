import Foundation
import Combine

@MainActor
final class TraceabilityViewModel: ObservableObject {
    let service = TraceabilityService()
}
