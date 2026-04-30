import Foundation

enum GoodsChecklistTemplateItem: String, Codable, CaseIterable {
    case productAppearance = "Aspetto del prodotto"
    case packageState = "Stato di confezionamento"
    case expiryDate = "Data di scadenza"
    case orderConformity = "Conformita dell'ordine"
    case noThawingSigns = "Assenza di segni di scongelamento"
    case noMold = "Assenza muffe o deterioramento"
    case freshness = "Maturazione / freschezza"
    case temperatureCompliant = "Temperatura conforme"
}

struct GoodsReceiptRequirement {
    let requiresTemperature: Bool
    let requiresLot: Bool
    let requiresExpiryDate: Bool
    let requiresProductionDate: Bool
    let requiresChecklist: Bool
    let requiresNotes: Bool
    let requiresPackagingCheck: Bool
    let requiresAppearanceCheck: Bool
    let defaultMinTemp: Double?
    let defaultMaxTemp: Double?
    let checklistItems: [GoodsChecklistTemplateItem]
}
