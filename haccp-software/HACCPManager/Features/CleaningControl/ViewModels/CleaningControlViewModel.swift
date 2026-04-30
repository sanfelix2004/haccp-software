import Foundation
import Combine

@MainActor
final class CleaningControlViewModel: ObservableObject {
    let service = CleaningControlService()
}
