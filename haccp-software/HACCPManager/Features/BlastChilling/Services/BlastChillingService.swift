import Foundation
import SwiftData

struct BlastChillingService {

    private static let activeDuplicateFetchLimit = 1

    func startRecord(
        restaurantId: UUID,
        subject: KitchenProcessSubject,
        startedAt: Date,
        initialTemperature: Double,
        targetTemperature: Double,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> BlastChillingRecord {
        guard subject.isValid else {
            throw blastError(
                code: 9008,
                message: "Seleziona un prodotto valido per l'abbattimento."
            )
        }
        let validation = BlastChillingValidationService().validateStart(
            startedAt: startedAt,
            initialTemperature: initialTemperature
        )
        guard validation.canSubmit else {
            throw blastError(
                code: 9001,
                message: validation.message ?? "Controlla i dati abbattimento."
            )
        }

        if let productionId = subject.productionId,
           try hasActiveInProgress(
               restaurantId: restaurantId,
               productionId: productionId,
               modelContext: modelContext
           ) {
            throw blastError(
                code: 9005,
                message: "Esiste già un abbattimento in corso per questo piatto."
            )
        }

        if let traceId = subject.traceabilityItemId,
           try hasActiveInProgress(
               restaurantId: restaurantId,
               traceabilityItemId: traceId,
               modelContext: modelContext
           ) {
            throw blastError(
                code: 9009,
                message: "Esiste già un abbattimento in corso per questo lotto tracciato."
            )
        }

        let now = Date()
        let record = BlastChillingRecord(
            restaurantId: restaurantId,
            productionId: subject.productionId,
            traceabilityItemId: subject.traceabilityItemId,
            lotNumberSnapshot: subject.lotNumber,
            productionNameSnapshot: subject.displayTitle,
            productionCategorySnapshot: subject.categoryName ?? (subject.source == .traceability ? "Tracciabilità" : "—"),
            startedAt: startedAt,
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

    func startRecord(
        restaurantId: UUID,
        production: Production,
        startedAt: Date,
        initialTemperature: Double,
        targetTemperature: Double,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> BlastChillingRecord {
        try startRecord(
            restaurantId: restaurantId,
            subject: .from(production: production),
            startedAt: startedAt,
            initialTemperature: initialTemperature,
            targetTemperature: targetTemperature,
            user: user,
            modelContext: modelContext
        )
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
        record.endedAt = max(Date(), record.startedAt)
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

    private func hasActiveInProgress(
        restaurantId: UUID,
        productionId: UUID,
        modelContext: ModelContext
    ) throws -> Bool {
        let rid = restaurantId
        let pid = productionId
        let inCorso = BlastChillingStatus.inCorso.rawValue
        var descriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { record in
                record.restaurantId == rid
                    && record.productionId == pid
                    && record.statusRaw == inCorso
                    && record.endedAt == nil
                    && !record.isArchived
            }
        )
        descriptor.fetchLimit = Self.activeDuplicateFetchLimit
        return try !modelContext.fetch(descriptor).isEmpty
    }

    private func hasActiveInProgress(
        restaurantId: UUID,
        traceabilityItemId: UUID,
        modelContext: ModelContext
    ) throws -> Bool {
        let rid = restaurantId
        let traceId = traceabilityItemId
        let inCorso = BlastChillingStatus.inCorso.rawValue
        var descriptor = FetchDescriptor<BlastChillingRecord>(
            predicate: #Predicate { record in
                record.restaurantId == rid
                    && record.traceabilityItemId == traceId
                    && record.statusRaw == inCorso
                    && record.endedAt == nil
                    && !record.isArchived
            }
        )
        descriptor.fetchLimit = Self.activeDuplicateFetchLimit
        return try !modelContext.fetch(descriptor).isEmpty
    }

    private func blastError(code: Int, message: String) -> NSError {
        NSError(domain: "BlastChillingService", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
