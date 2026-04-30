import Foundation
import Combine

@MainActor
final class OilControlViewModel: ObservableObject {
    let service = OilControlService()
}
