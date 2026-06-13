import Foundation
import SwiftData

enum ProductionLabelLookupService {

    @MainActor
    static func fetchLabel(
        id: UUID,
        restaurantId: UUID?,
        context: ModelContext
    ) throws -> ProductionLabelRecord? {
        var descriptor = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let label = try context.fetch(descriptor).first else { return nil }

        if let restaurantId, label.restaurantId != restaurantId {
            return nil
        }
        return label
    }
}
