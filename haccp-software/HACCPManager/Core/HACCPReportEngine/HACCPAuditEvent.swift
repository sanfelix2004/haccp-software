//
//  HACCPAuditEvent.swift
//  HACCP Manager — Report Engine
//
//  Audit trail unificato per il motore report. Non sostituisce gli audit log
//  esistenti (ChecklistAuditLog / TemperatureAuditLog / TraceabilityLog) ma li
//  affianca con eventi di alto livello su report, sync, firme, revisioni.
//

import Foundation
import SwiftData

@Model
final class HACCPAuditEvent {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID

    var actionRaw: String
    var severityRaw: String

    /// Modulo/area logica (es. "REPORT_ENGINE", "DOCUMENT", "ICLOUD_SYNC", "SCHEDULER").
    var module: String
    /// Sottotipo libero per categorizzazione (es. "DAILY_GENERATION").
    var subject: String

    /// ID dell'entità oggetto dell'evento (DocumentItem.id, RevisionId, ...).
    var entityId: UUID?
    /// Identificativo human-readable dell'entità (filename, codice, ...).
    var entityRef: String

    var userId: UUID?
    var userNameSnapshot: String

    /// Stato/valore precedente serializzato (es. JSON, hash, "v1").
    var previousValue: String?
    /// Stato/valore nuovo serializzato.
    var newValue: String?

    var details: String?
    var timestamp: Date

    var action: HACCPAuditAction {
        get { HACCPAuditAction(rawValue: actionRaw) ?? .update }
        set { actionRaw = newValue.rawValue }
    }

    var severity: HACCPEventSeverity {
        get { HACCPEventSeverity(rawValue: severityRaw) ?? .info }
        set { severityRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        action: HACCPAuditAction,
        severity: HACCPEventSeverity = .info,
        module: String,
        subject: String,
        entityId: UUID? = nil,
        entityRef: String = "",
        userId: UUID? = nil,
        userNameSnapshot: String = "",
        previousValue: String? = nil,
        newValue: String? = nil,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.actionRaw = action.rawValue
        self.severityRaw = severity.rawValue
        self.module = module
        self.subject = subject
        self.entityId = entityId
        self.entityRef = entityRef
        self.userId = userId
        self.userNameSnapshot = userNameSnapshot
        self.previousValue = previousValue
        self.newValue = newValue
        self.details = details
        self.timestamp = timestamp
    }
}

// MARK: - Manager

/// Gestione centralizzata dell'audit trail HACCP del motore report.
@MainActor
final class HACCPAuditManager {
    static let shared = HACCPAuditManager()
    private init() {}

    /// Numero massimo di eventi mantenuti per ristorante (oltre il limite si compatta in archivio).
    var retentionLimitPerRestaurant: Int = 25_000

    // MARK: Recording

    @discardableResult
    func record(
        in modelContext: ModelContext,
        restaurantId: UUID,
        action: HACCPAuditAction,
        severity: HACCPEventSeverity = .info,
        module: String,
        subject: String,
        entityId: UUID? = nil,
        entityRef: String = "",
        user: LocalUser? = nil,
        previousValue: String? = nil,
        newValue: String? = nil,
        details: String? = nil
    ) -> HACCPAuditEvent {
        let event = HACCPAuditEvent(
            restaurantId: restaurantId,
            action: action,
            severity: severity,
            module: module,
            subject: subject,
            entityId: entityId,
            entityRef: entityRef,
            userId: user?.id,
            userNameSnapshot: user?.name ?? "",
            previousValue: previousValue,
            newValue: newValue,
            details: details
        )
        modelContext.insert(event)
        try? modelContext.save()
        return event
    }

    // MARK: Querying

    func events(
        in modelContext: ModelContext,
        restaurantId: UUID,
        interval: DateInterval? = nil,
        module: String? = nil,
        minSeverity: HACCPEventSeverity? = nil
    ) -> [HACCPAuditEvent] {
        let descriptor = FetchDescriptor<HACCPAuditEvent>()
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        return all
            .filter { $0.restaurantId == restaurantId }
            .filter { interval?.contains($0.timestamp) ?? true }
            .filter { module == nil || $0.module == module }
            .filter { minSeverity == nil || $0.severity.weight >= (minSeverity?.weight ?? 0) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func eventCount(in modelContext: ModelContext, restaurantId: UUID) -> Int {
        events(in: modelContext, restaurantId: restaurantId).count
    }

    /// Esegue cleanup se gli eventi superano la soglia di retention (FIFO sui più vecchi).
    func enforceRetention(in modelContext: ModelContext, restaurantId: UUID) {
        let all = events(in: modelContext, restaurantId: restaurantId)
        guard all.count > retentionLimitPerRestaurant else { return }
        let surplus = all.count - retentionLimitPerRestaurant
        for evt in all.suffix(surplus) {
            modelContext.delete(evt)
        }
        try? modelContext.save()
    }
}
