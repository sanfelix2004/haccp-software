//
//  DefrostService.swift
//

import Foundation
import SwiftData

struct DefrostService {

    /// Temperatura massima sicura post-decongelamento in frigo (°C).
    static let maxSafeTemperatureCelsius: Double = 4.0

    func startDefrost(
        draft: DefrostNewDraft,
        restaurantId: UUID,
        user: LocalUser,
        settings: HACCPSettings,
        modelContext: ModelContext
    ) throws -> DefrostRecord {
        let name = draft.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw defrostError("Il nome prodotto è obbligatorio.")
        }

        let startAt = Date()
        let expectedEndAt = draft.method.expectedEndAt(from: startAt, settings: settings)

        let record = DefrostRecord(
            restaurantId: restaurantId,
            productName: name,
            method: draft.method,
            lotNumber: draft.lotNumber.nilIfEmpty,
            traceabilityItemId: draft.traceabilityItemId,
            productTemplateId: draft.productTemplateId,
            productionId: draft.productionId,
            categoryNameSnapshot: draft.categoryName,
            startAt: startAt,
            expectedEndAt: expectedEndAt,
            status: .inProgress,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: draft.notes.nilIfEmpty,
            operatorSignature: user.name
        )
        modelContext.insert(record)
        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
        return record
    }

    func completeDefrost(
        record: DefrostRecord,
        draft: DefrostCompleteDraft,
        user: LocalUser,
        modelContext: ModelContext,
        criticalities: [DefrostCriticality]
    ) throws {
        guard record.endAt == nil else {
            throw defrostError("Questo decongelamento è già stato completato.")
        }

        let temp = Double(draft.finalTemperature.replacingOccurrences(of: ",", with: "."))
        let tempNonConforme = isTemperatureNonConforme(
            method: record.defrostMethod,
            temperature: temp
        )
        let outcome: DefrostOutcome = draft.outcome == .nonConforme || tempNonConforme
            ? .nonConforme
            : .conforme

        if outcome == .nonConforme {
            let reason = draft.criticalityReason.nilIfEmpty ?? "Temperatura o condizioni non conformi"
            let action = draft.correctiveAction.nilIfEmpty ?? ""
            guard !action.isEmpty else {
                throw defrostError("Inserisci l'azione correttiva per la non conformità.")
            }
            createCriticality(
                record: record,
                reason: reason,
                correctiveAction: action,
                user: user,
                modelContext: modelContext
            )
        }

        let endAt = max(Date(), record.startAt)
        record.endAt = endAt
        record.finalTemperature = temp
        record.outcome = outcome
        record.notes = mergedNotes(record.notes, draft.notes)
        record.correctiveAction = draft.correctiveAction.nilIfEmpty
        record.updatedAt = Date()
        record.defrostStatus = outcome == .nonConforme ? .completedWithCriticality : .completed

        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
    }

    func cancelDefrost(_ record: DefrostRecord, modelContext: ModelContext) throws {
        guard record.endAt == nil else {
            throw defrostError("Non puoi annullare un decongelamento già completato.")
        }
        let now = Date()
        record.defrostStatus = .cancelled
        record.endAt = max(now, record.startAt)
        record.updatedAt = now
        try modelContext.save()
        KitchenProcessNotifications.postRecordsDidChange()
    }

    func deleteDefrost(
        _ record: DefrostRecord,
        criticalities: [DefrostCriticality],
        modelContext: ModelContext
    ) throws {
        for c in criticalities where c.recordId == record.id {
            modelContext.delete(c)
        }
        modelContext.delete(record)
        try modelContext.save()
    }

    func resolveCriticality(
        _ criticality: DefrostCriticality,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        criticality.isResolved = true
        criticality.resolvedAt = Date()
        criticality.resolvedByUserId = user.id
        criticality.resolvedByNameSnapshot = user.name
        try modelContext.save()
    }

    func openCriticality(for recordId: UUID, in criticalities: [DefrostCriticality]) -> DefrostCriticality? {
        criticalities.first { $0.recordId == recordId && !$0.isResolved }
    }

    func refreshDelayedStatuses(records: [DefrostRecord], settings: HACCPSettings) {
        _ = refreshDelayedStatusesIfNeeded(records: records, settings: settings)
    }

    /// Aggiorna stati ritardati solo se cambiano — evita `save()` inutili su ogni refresh.
    @discardableResult
    func refreshDelayedStatusesIfNeeded(records: [DefrostRecord], settings: HACCPSettings) -> Bool {
        let now = Date()
        var changed = false
        for record in records where record.isActive {
            if record.expectedEndAt == nil {
                record.expectedEndAt = record.defrostMethod.expectedEndAt(from: record.startAt, settings: settings)
                changed = true
            }
            let before = record.statusRaw
            record.refreshComputedStatus(at: now)
            if record.statusRaw != before {
                changed = true
            }
        }
        return changed
    }

    func draft(from production: Production) -> DefrostNewDraft {
        var d = DefrostNewDraft()
        d.productName = production.name
        d.productionId = production.id
        d.categoryName = production.categoryNameSnapshot
        return d
    }

    func draft(from trace: TraceabilityRecord) -> DefrostNewDraft {
        var d = DefrostNewDraft()
        d.productName = trace.productName
        d.lotNumber = trace.lotCode
        d.traceabilityItemId = trace.id
        return d
    }

    func isTemperatureNonConforme(method: DefrostMethod, temperature: Double?) -> Bool {
        guard let temperature else { return false }
        switch method {
        case .frigorifero, .temperaturaControllata:
            return temperature > Self.maxSafeTemperatureCelsius
        default:
            return false
        }
    }

    private func createCriticality(
        record: DefrostRecord,
        reason: String,
        correctiveAction: String,
        user: LocalUser,
        modelContext: ModelContext
    ) {
        modelContext.insert(
            DefrostCriticality(
                restaurantId: record.restaurantId,
                recordId: record.id,
                productName: record.productName,
                reason: reason,
                correctiveAction: correctiveAction,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
        )
    }

    private func mergedNotes(_ existing: String?, _ added: String) -> String? {
        let a = added.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty else { return existing }
        if let existing, !existing.isEmpty { return "\(existing)\n\(a)" }
        return a
    }

    private func defrostError(_ message: String) -> NSError {
        NSError(domain: "DefrostService", code: 4300, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
