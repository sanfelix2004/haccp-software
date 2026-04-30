import Foundation
import Combine

@MainActor
final class ProductionLabelsViewModel: ObservableObject {
    let service = ProductionLabelsService()
}
