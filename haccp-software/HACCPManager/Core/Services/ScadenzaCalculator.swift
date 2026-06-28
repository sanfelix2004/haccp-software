import Foundation
import SwiftData

/// Calcolo centralizzato delle date di scadenza per alimenti in ingresso e produzioni.
enum ScadenzaCalculator {

    // MARK: - Alimenti in ingresso

    /// Giorni di conservazione suggeriti per un alimento in ingresso.
    static func shelfLifeDays(for template: ProductTemplate) -> Int {
        if let explicit = template.shelfLifeDays, explicit > 0 {
            return explicit
        }
        return IncomingFoodShelfLifeDefaults.days(forName: template.name, category: template.category)
    }

    /// Giorni di conservazione per una produzione/piatto finito.
    static func shelfLifeDays(for production: Production) -> Int {
        if let explicit = production.shelfLifeDays, explicit > 0 {
            return explicit
        }
        return ProductionShelfLifeDefaults.days(
            forName: production.name,
            categoryName: production.categoryNameSnapshot
        )
    }

    /// Data di scadenza suggerita a partire da una data di riferimento (es. ricezione o scatto).
    static func suggestedExpiryDate(
        for template: ProductTemplate,
        from referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        expiryDate(fromDays: shelfLifeDays(for: template), referenceDate: referenceDate, calendar: calendar)
    }

    /// Scadenza calcolata da numero giorni esplicito (override in tracciabilità).
    static func expiryDate(
        fromDays days: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let safeDays = max(0, days)
        return calendar.date(byAdding: .day, value: safeDays, to: calendar.startOfDay(for: referenceDate))
            ?? referenceDate
    }

    /// Scadenza interna produzione da giorni espliciti.
    static func productionExpiryDate(
        fromDays days: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        expiryDate(fromDays: days, referenceDate: referenceDate, calendar: calendar)
    }

    // MARK: - Vincolo minimo ingredienti (HACCP)

    /// Risultato del calcolo: min(durata catalogo, scadenza ingrediente più vicina).
    struct ProductionExpiryConstraint: Equatable {
        let catalogExpiryDate: Date
        let ingredientConstraintDate: Date?
        let suggestedExpiryDate: Date
        let limitingIngredientName: String?
        let shelfLifeDays: Int

        var isIngredientLimited: Bool {
            limitingIngredientName != nil
        }
    }

    /// Regola FEFO HACCP: la scadenza del piatto finito non può superare quella del limite ingrediente.
    static func productionExpiryConstraint(
        shelfLifeDays: Int,
        ingredientRecords: [TraceabilityRecord],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> ProductionExpiryConstraint {
        let safeDays = max(0, shelfLifeDays)
        let catalogDate = productionExpiryDate(
            fromDays: safeDays,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let datedIngredients: [(name: String, expiry: Date)] = ingredientRecords.compactMap { record in
            guard let expiry = record.expiryDate else { return nil }
            return (record.productName, calendar.startOfDay(for: expiry))
        }

        let nearest = datedIngredients.min(by: { $0.expiry < $1.expiry })
        let ingredientDate = nearest?.expiry

        let suggested: Date
        let limitingName: String?
        if let ingredientDate {
            if ingredientDate < catalogDate {
                suggested = ingredientDate
                limitingName = nearest?.name
            } else {
                suggested = catalogDate
                limitingName = nil
            }
        } else {
            suggested = catalogDate
            limitingName = nil
        }

        return ProductionExpiryConstraint(
            catalogExpiryDate: catalogDate,
            ingredientConstraintDate: ingredientDate,
            suggestedExpiryDate: suggested,
            limitingIngredientName: limitingName,
            shelfLifeDays: safeDays
        )
    }

    /// Scadenza effettiva applicata (con opzione forzatura durata catalogo post-cottura).
    static func resolvedProductionExpiry(
        shelfLifeDays: Int,
        ingredientRecords: [TraceabilityRecord],
        ignoreIngredientConstraint: Bool = false,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> ProductionExpiryConstraint {
        let constraint = productionExpiryConstraint(
            shelfLifeDays: shelfLifeDays,
            ingredientRecords: ingredientRecords,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard ignoreIngredientConstraint else { return constraint }
        return ProductionExpiryConstraint(
            catalogExpiryDate: constraint.catalogExpiryDate,
            ingredientConstraintDate: constraint.ingredientConstraintDate,
            suggestedExpiryDate: constraint.catalogExpiryDate,
            limitingIngredientName: nil,
            shelfLifeDays: constraint.shelfLifeDays
        )
    }

    // MARK: - Produzioni / piatti finiti (legacy)

    /// Giorni di conservazione interna per un prodotto finito (ricetta o fallback catalogo).
    static func productionShelfLifeDays(
        productionId: UUID,
        productionName: String,
        modelContext: ModelContext
    ) -> Int? {
        let productionDescriptor = FetchDescriptor<Production>()
        if let production = ((try? modelContext.fetch(productionDescriptor)) ?? [])
            .first(where: { $0.id == productionId }) {
            if let explicit = production.shelfLifeDays, explicit > 0 {
                return explicit
            }
            return shelfLifeDays(for: production)
        }

        return ProductionShelfLifeDefaults.days(forName: productionName, categoryName: "")
    }

    /// Scadenza interna suggerita per un prodotto finito.
    static func suggestedProductionExpiryDate(
        productionId: UUID,
        productionName: String,
        modelContext: ModelContext,
        from referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard let days = productionShelfLifeDays(
            productionId: productionId,
            productionName: productionName,
            modelContext: modelContext
        ) else { return nil }
        return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: referenceDate))
    }
}

extension ProductTemplate {
    /// Durata effettiva (esplicita o da mappa default).
    var defaultShelfLifeDays: Int {
        ScadenzaCalculator.shelfLifeDays(for: self)
    }
}

extension Production {
    var defaultShelfLifeDays: Int {
        ScadenzaCalculator.shelfLifeDays(for: self)
    }
}
