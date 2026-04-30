import Foundation
import Combine

@MainActor
final class DefrostViewModel: ObservableObject {
    let service = DefrostService()
}
