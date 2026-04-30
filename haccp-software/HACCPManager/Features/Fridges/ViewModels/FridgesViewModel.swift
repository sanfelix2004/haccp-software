import Foundation
import Combine

@MainActor
final class FridgesViewModel: ObservableObject {
    let service = FridgesService()
}
