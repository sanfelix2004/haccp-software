import Foundation

enum KitchenProcessSubjectSource: String, CaseIterable, Identifiable {
    case traceability = "Lotti tracciati"
    case incomingFood = "Alimenti in ingresso"
    case production = "Alimenti Produzione"
    case manual = "Manuale"

    var id: String { rawValue }
}

/// Oggetto su cui si applica un processo cucina (decongelamento, abbattimento, …).
struct KitchenProcessSubject: Equatable {
    var source: KitchenProcessSubjectSource
    var traceabilityItemId: UUID?
    var productTemplateId: UUID?
    var productionId: UUID?
    var productName: String
    var lotNumber: String?
    var categoryName: String?

    var displayTitle: String {
        productName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displaySubtitle: String {
        var parts: [String] = []
        if let categoryName, !categoryName.isEmpty { parts.append(categoryName) }
        if let lotNumber, !lotNumber.isEmpty { parts.append("Lotto \(lotNumber)") }
        if parts.isEmpty {
            switch source {
            case .traceability: return "Lotto tracciato (ricezione)"
            case .incomingFood: return "Catalogo alimenti in ingresso"
            case .production: return "Alimenti Produzione"
            case .manual: return "Inserimento manuale"
            }
        }
        return parts.joined(separator: " · ")
    }

    var isValid: Bool {
        let nameOk = !displayTitle.isEmpty
        switch source {
        case .traceability:
            return nameOk && traceabilityItemId != nil
        case .incomingFood:
            return nameOk && productTemplateId != nil
        case .production:
            return nameOk && productionId != nil
        case .manual:
            return nameOk
        }
    }

    static func from(trace: TraceabilityRecord) -> KitchenProcessSubject {
        KitchenProcessSubject(
            source: .traceability,
            traceabilityItemId: trace.id,
            productTemplateId: nil,
            productionId: nil,
            productName: trace.productName,
            lotNumber: trace.lotCode,
            categoryName: trace.categoryRaw
        )
    }

    static func from(template: ProductTemplate) -> KitchenProcessSubject {
        KitchenProcessSubject(
            source: .incomingFood,
            traceabilityItemId: nil,
            productTemplateId: template.id,
            productionId: nil,
            productName: template.name,
            lotNumber: nil,
            categoryName: template.category.rawValue
        )
    }

    static func from(production: Production) -> KitchenProcessSubject {
        KitchenProcessSubject(
            source: .production,
            traceabilityItemId: nil,
            productTemplateId: nil,
            productionId: production.id,
            productName: production.name,
            lotNumber: nil,
            categoryName: production.categoryNameSnapshot
        )
    }

    func pseudoProduction(restaurantId: UUID) -> Production {
        Production(
            id: productionId ?? traceabilityItemId ?? productTemplateId ?? UUID(),
            restaurantId: restaurantId,
            name: displayTitle,
            categoryId: productionId ?? UUID(),
            categoryNameSnapshot: categoryName ?? sourceLabel,
            isCustom: source != .production
        )
    }

    private var sourceLabel: String {
        switch source {
        case .traceability: return "Tracciabilità"
        case .incomingFood: return "Alimento in ingresso"
        case .production: return "Piatto"
        case .manual: return "Manuale"
        }
    }
}

enum KitchenProcessSubjectFactory {
    static func actionableTraceability(_ records: [TraceabilityRecord]) -> [TraceabilityRecord] {
        records.filter { record in
            record.productStatus != .rejected && record.productStatus != .expired
        }
    }
}
