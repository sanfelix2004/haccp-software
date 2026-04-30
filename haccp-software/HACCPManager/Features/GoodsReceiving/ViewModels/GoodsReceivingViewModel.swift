import Foundation
import Combine

@MainActor
final class GoodsReceivingViewModel: ObservableObject {
    let service = GoodsReceivingService()
}
