import Foundation
import Combine

@MainActor
final class ProductionSelectionViewModel: ObservableObject {
    @Published var selectedCategoryId: UUID?
    @Published var selectedProductionIds: Set<UUID> = []
    @Published var isEditMode = false
    @Published var showAddSheet = false
    @Published var newProductionName = ""
    @Published var newProductionCategoryId: UUID?
}
