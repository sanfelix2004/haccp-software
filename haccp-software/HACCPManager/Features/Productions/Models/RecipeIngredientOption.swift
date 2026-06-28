import Foundation

/// Opzione ingrediente ricetta per selezione rapida (alimento in ingresso).
struct RecipeIngredientOption: Identifiable, Equatable {
    let name: String
    let productTemplateId: UUID?

    var id: String { productTemplateId?.uuidString ?? name }

    init(name: String, productTemplateId: UUID? = nil) {
        self.name = name
        self.productTemplateId = productTemplateId
    }

    init(link: ProductionIncomingIngredient) {
        self.name = link.productNameSnapshot
        self.productTemplateId = link.productTemplateId
    }
}
