import Foundation
import Combine

@MainActor
final class GoodsReceiptControlViewModel: ObservableObject {
    @Published var receivedAt: Date = Date()
    @Published var temperatureText: String = ""
    @Published var lotNumber: String = ""
    @Published var expiryDate: Date = Date()
    @Published var includeExpiryDate = false
    @Published var productionDate: Date = Date()
    @Published var includeProductionDate = false
    @Published var quantityText: String = ""
    @Published var unit: String = "kg"
    @Published var notes: String = ""
    @Published var correctiveAction: String = ""
    @Published var photoData: Data?
    @Published var checklistResults: [GoodsReceiptChecklistResult] = []
    @Published var infoMessage: String?

    func bootstrap(requirement: GoodsReceiptRequirement, product: ProductTemplate? = nil) {
        receivedAt = Date()
        temperatureText = ""
        lotNumber = ""
        productionDate = Date()
        quantityText = ""
        unit = "kg"
        notes = ""
        correctiveAction = ""
        photoData = nil
        includeExpiryDate = requirement.requiresExpiryDate
        includeProductionDate = requirement.requiresProductionDate
        if let product {
            expiryDate = ScadenzaCalculator.suggestedExpiryDate(for: product, from: receivedAt)
            includeExpiryDate = true
        } else {
            expiryDate = Date()
        }
        checklistResults = requirement.checklistItems.map { GoodsReceiptChecklistResult(item: $0) }
    }

    var temperatureValue: Double? {
        Double(temperatureText.replacingOccurrences(of: ",", with: "."))
    }

    var quantityValue: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }
}
