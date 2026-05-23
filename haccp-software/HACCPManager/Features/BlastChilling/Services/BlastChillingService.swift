import Foundation
import SwiftData

struct BlastChillingService {
    func startRecord(
        restaurantId: UUID,
        production: Production,
        startedAt: Date,
        initialTemperature: Double,
        targetTemperature: Double,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> BlastChillingRecord {
        let validation = BlastChillingValidationService().validateStart(
            startedAt: startedAt,
            initialTemperature: initialTemperature
        )
        guard validation.canSubmit else {
            throw NSError(
                domain: "BlastChillingService",
                code: 9001,
                userInfo: [NSLocalizedDescriptionKey: validation.message ?? "Controlla i dati abbattimento."]
            )
        }
        let existingInProgress = (try? modelContext.fetch(FetchDescriptor<BlastChillingRecord>()))?
            .contains {
                $0.restaurantId == restaurantId &&
                $0.productionId == production.id &&
                $0.status == .inCorso
            } ?? false
        guard !existingInProgress else {
            throw NSError(domain: "BlastChillingService", code: 9005, userInfo: [NSLocalizedDescriptionKey: "Esiste già un abbattimento in corso per questa produzione."])
        }

        let now = Date()
        let safeStartedAt = min(startedAt, now)
        let record = BlastChillingRecord(
            restaurantId: restaurantId,
            productionId: production.id,
            productionNameSnapshot: production.name,
            productionCategorySnapshot: production.categoryNameSnapshot,
            startedAt: safeStartedAt,
            initialTemperature: initialTemperature,
            targetTemperature: targetTemperature,
            status: .inCorso,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            createdAt: now,
            updatedAt: now,
            operatorSignature: user.name
        )
        modelContext.insert(record)
        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
        return record
    }

    func completeRecord(
        _ record: BlastChillingRecord,
        endedAt: Date,
        finalTemperature: Double,
        notes: String?,
        correctiveAction: String?,
        modelContext: ModelContext
    ) throws {
        let validation = BlastChillingValidationService().validateCompletion(
            startedAt: record.startedAt,
            endedAt: endedAt,
            finalTemperature: finalTemperature,
            targetTemperature: record.targetTemperature,
            notes: notes,
            correctiveAction: correctiveAction
        )
        guard validation.canSubmit else {
            throw NSError(
                domain: "BlastChillingService",
                code: 9006,
                userInfo: [NSLocalizedDescriptionKey: validation.message ?? "Controlla i dati di fine abbattimento."]
            )
        }
        record.endedAt = max(endedAt, record.startedAt)
        record.finalTemperature = finalTemperature
        record.status = validation.status
        record.notes = trimmedOrNil(notes)
        record.correctiveAction = trimmedOrNil(correctiveAction)
        record.updatedAt = Date()
        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
    }

    func cancelRecord(_ record: BlastChillingRecord, modelContext: ModelContext) throws {
        guard record.status == .inCorso else {
            throw NSError(
                domain: "BlastChillingService",
                code: 9007,
                userInfo: [NSLocalizedDescriptionKey: "L'abbattimento non è più in corso."]
            )
        }
        let now = Date()
        record.endedAt = max(now, record.startedAt)
        record.status = .annullato
        record.updatedAt = now
        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
    }

    func addProduction(
        name: String,
        category: ProductionCategory,
        restaurantId: UUID,
        existingProductions: [Production],
        modelContext: ModelContext
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exists = existingProductions.contains {
            $0.restaurantId == restaurantId &&
            $0.categoryId == category.id &&
            normalized($0.name) == normalized(trimmed)
        }
        guard !exists else {
            throw NSError(domain: "BlastChillingService", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Produzione già presente in questa categoria."])
        }
        modelContext.insert(
            Production(
                restaurantId: restaurantId,
                name: trimmed,
                categoryId: category.id,
                categoryNameSnapshot: category.name,
                isCustom: true
            )
        )
        try modelContext.save()
    }

    func updateProduction(
        _ production: Production,
        name: String,
        category: ProductionCategory,
        existingProductions: [Production],
        modelContext: ModelContext
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exists = existingProductions.contains {
            $0.id != production.id &&
            $0.restaurantId == production.restaurantId &&
            $0.categoryId == category.id &&
            normalized($0.name) == normalized(trimmed)
        }
        guard !exists else {
            throw NSError(domain: "BlastChillingService", code: 9003, userInfo: [NSLocalizedDescriptionKey: "Esiste già una produzione con questo nome nella categoria."])
        }
        production.name = trimmed
        production.categoryId = category.id
        production.categoryNameSnapshot = category.name
        try modelContext.save()
    }

    func deleteProductionIfUnused(
        _ production: Production,
        records: [BlastChillingRecord],
        modelContext: ModelContext
    ) throws {
        guard records.contains(where: { $0.productionId == production.id }) == false else {
            throw NSError(domain: "BlastChillingService", code: 9004, userInfo: [NSLocalizedDescriptionKey: "Produzione già usata nello storico: non può essere eliminata."])
        }
        modelContext.delete(production)
        try modelContext.save()
    }

    private func trimmedOrNil(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
