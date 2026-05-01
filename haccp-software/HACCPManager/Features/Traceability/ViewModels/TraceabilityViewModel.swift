import Foundation
import Combine

@MainActor
final class TraceabilityViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case photo = "Foto"
        case date = "Data"
        case lot = "N lotto / scadenza"
        case notes = "Appunti"

        var id: String { rawValue }
    }

    @Published var selectedTab: Tab = .photo
    @Published var productName = ""
    @Published var supplier = ""
    @Published var selectedSupplierId: UUID?
    @Published var lotCode = ""
    @Published var productionReference = ""
    @Published var notes = ""
    @Published var receivedAt = Date()
    @Published var expiryDate = Date()
    @Published var includeExpiryDate = false
    @Published var photoData: Data?
    @Published var errorMessage: String?

    let service = TraceabilityService()

    var canSave: Bool {
        photoData != nil &&
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedSupplierId != nil &&
        !supplier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func resetForNext() {
        productName = ""
        supplier = ""
        selectedSupplierId = nil
        lotCode = ""
        productionReference = ""
        notes = ""
        receivedAt = Date()
        expiryDate = Date()
        includeExpiryDate = false
        photoData = nil
        selectedTab = .photo
    }
}
