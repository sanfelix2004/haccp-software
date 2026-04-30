import Foundation
import Combine

@MainActor
final class BlastChillingViewModel: ObservableObject {
    let service = BlastChillingService()
}
