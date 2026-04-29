import Foundation
import SwiftData

@MainActor
final class ChecklistService {
    private let validationService = ChecklistValidationService()
    private let scheduleService = ChecklistScheduleService()
    private let notificationService = ChecklistNotificationService()

    func createTemplate(
        restaurantId: UUID,
        title: String,
        description: String,
        category: ChecklistCategory,
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        createdBy: LocalUser,
        items: [ChecklistItemTemplateDraft],
        modelContext: ModelContext
    ) throws -> ChecklistTemplate {
        let template = ChecklistTemplate(
            restaurantId: restaurantId,
            title: title,
            checklistDescription: description,
            category: category,
            frequency: frequency,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            isActive: true,
            isSuggestedLibrary: false,
            createdByUserId: createdBy.id
        )
        modelContext.insert(template)

        for (index, draft) in items.enumerated() {
            let item = ChecklistItemTemplate(
                checklistTemplateId: template.id,
                title: draft.title,
                itemDescription: draft.description,
                type: draft.type,
                isRequired: draft.isRequired,
                orderIndex: index,
                requiresNoteIfFailed: draft.requiresNoteIfFailed
            )
            modelContext.insert(item)
        }

        log(
            restaurantId: restaurantId,
            user: createdBy,
            action: "CHECKLIST_TEMPLATE_CREATED",
            entityId: template.id,
            details: title,
            modelContext: modelContext
        )
        try modelContext.save()
        return template
    }

    func activateSuggestedTemplate(
        suggestedTemplate: SuggestedChecklistTemplate,
        restaurantId: UUID,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> ChecklistTemplate {
        try createTemplate(
            restaurantId: restaurantId,
            title: suggestedTemplate.title,
            description: suggestedTemplate.description,
            category: suggestedTemplate.category,
            frequency: suggestedTemplate.frequency,
            scheduledHour: suggestedTemplate.scheduledHour,
            scheduledMinute: suggestedTemplate.scheduledMinute,
            createdBy: user,
            items: suggestedTemplate.items,
            modelContext: modelContext
        )
    }

    func seedDefaultTemplatesIfNeeded(
        restaurantId: UUID,
        createdBy: LocalUser,
        modelContext: ModelContext
    ) throws {
        let existingTemplates = (try? modelContext.fetch(FetchDescriptor<ChecklistTemplate>())) ?? []
        let existingTitles = Set(
            existingTemplates
                .filter { $0.restaurantId == restaurantId && !$0.isSuggestedLibrary }
                .map { $0.title.lowercased() }
        )

        for def in defaultTemplateDefinitions {
            if existingTitles.contains(def.title.lowercased()) {
                continue
            }
            _ = try createTemplate(
                restaurantId: restaurantId,
                title: def.title,
                description: def.description,
                category: def.category,
                frequency: def.frequency,
                scheduledHour: def.scheduledHour,
                scheduledMinute: def.scheduledMinute,
                createdBy: createdBy,
                items: def.items,
                modelContext: modelContext
            )
        }
    }

    func startRun(
        template: ChecklistTemplate,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws -> ChecklistRun {
        let run = ChecklistRun(
            restaurantId: restaurantId,
            templateId: template.id,
            templateTitleSnapshot: template.title,
            startedAt: Date(),
            dueAt: scheduleService.dueDateForCurrentCycle(
                frequency: template.frequency,
                scheduledHour: template.scheduledHour,
                scheduledMinute: template.scheduledMinute,
                anchorDate: template.createdAt
            ),
            status: .inProgress
        )
        modelContext.insert(run)

        let itemTemplates = (try? modelContext.fetch(FetchDescriptor<ChecklistItemTemplate>())) ?? []
        let scopedItems = itemTemplates
            .filter { $0.checklistTemplateId == template.id }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
        for item in scopedItems {
            let result = ChecklistItemResult(
                checklistRunId: run.id,
                itemTemplateId: item.id,
                titleSnapshot: item.title,
                result: .pending,
                orderIndex: item.orderIndex
            )
            modelContext.insert(result)
        }

        log(
            restaurantId: restaurantId,
            user: user,
            action: "CHECKLIST_RUN_STARTED",
            entityId: run.id,
            details: template.title,
            modelContext: modelContext
        )
        try modelContext.save()
        syncChecklistNotifications(restaurantId: restaurantId, modelContext: modelContext)
        return run
    }

    func updateItemResult(
        itemResult: ChecklistItemResult,
        result: ChecklistItemResultValue,
        note: String?,
        user: LocalUser,
        run: ChecklistRun,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws {
        itemResult.result = result
        itemResult.note = note
        itemResult.completedAt = Date()
        itemResult.completedByUserId = user.id

        let results = (try? modelContext.fetch(FetchDescriptor<ChecklistItemResult>())) ?? []
        let scopedResults = results.filter { $0.checklistRunId == run.id }
        let completedCount = scopedResults.filter { $0.result != .pending }.count
        run.progressPercentage = scopedResults.isEmpty ? 0 : (Double(completedCount) / Double(scopedResults.count)) * 100
        if completedCount == 0 {
            run.status = .notStarted
            run.completedAt = nil
            run.completedByUserId = nil
            run.completedByNameSnapshot = nil
        } else if completedCount < scopedResults.count {
            if run.status != .overdue {
                run.status = .inProgress
            }
            run.completedAt = nil
            run.completedByUserId = nil
            run.completedByNameSnapshot = nil
        } else {
            let hasFailure = scopedResults.contains(where: { $0.result == .fail })
            run.status = hasFailure ? .failed : .completed
            run.completedAt = Date()
            run.completedByUserId = user.id
            run.completedByNameSnapshot = user.name
        }

        if result == .fail {
            let alerts = (try? modelContext.fetch(FetchDescriptor<ChecklistAlert>())) ?? []
            let message = "Criticita: \(itemResult.titleSnapshot)"
            let alreadyExists = alerts.contains {
                $0.checklistRunId == run.id && $0.message == message && $0.isActive
            }
            if !alreadyExists {
                let alert = ChecklistAlert(
                    restaurantId: restaurantId,
                    checklistRunId: run.id,
                    severity: .high,
                    message: message
                )
                modelContext.insert(alert)
            }
            log(
                restaurantId: restaurantId,
                user: user,
                action: "CHECKLIST_ITEM_FAILED",
                entityId: itemResult.id,
                details: itemResult.titleSnapshot,
                modelContext: modelContext
            )
        }

        try modelContext.save()
    }

    func completeRun(
        run: ChecklistRun,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws -> (Bool, String?) {
        let itemTemplates = (try? modelContext.fetch(FetchDescriptor<ChecklistItemTemplate>())) ?? []
        let itemResults = (try? modelContext.fetch(FetchDescriptor<ChecklistItemResult>())) ?? []
            .filter { $0.checklistRunId == run.id }
        let scopedTemplates = itemTemplates.filter { item in
            itemResults.contains(where: { $0.itemTemplateId == item.id })
        }

        let validation = validationService.canCompleteRun(
            run: run,
            itemTemplates: scopedTemplates,
            itemResults: itemResults
        )
        guard validation.canComplete else {
            return (false, validation.message)
        }

        run.completedAt = Date()
        run.completedByUserId = user.id
        run.completedByNameSnapshot = user.name
        run.progressPercentage = 100
        run.status = validation.failedRequiredItems.isEmpty ? .completed : .failed

        if run.status == .failed {
            let alert = ChecklistAlert(
                restaurantId: restaurantId,
                checklistRunId: run.id,
                severity: .critical,
                message: "Checklist fallita: \(run.templateTitleSnapshot)"
            )
            modelContext.insert(alert)
        }

        log(
            restaurantId: restaurantId,
            user: user,
            action: "CHECKLIST_RUN_COMPLETED",
            entityId: run.id,
            details: run.status.rawValue,
            modelContext: modelContext
        )
        try modelContext.save()
        syncChecklistNotifications(restaurantId: restaurantId, modelContext: modelContext)
        return (true, nil)
    }

    func resolveAlert(
        _ alert: ChecklistAlert,
        correctiveAction: String,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let action = correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !action.isEmpty else {
            return
        }
        alert.isActive = false
        alert.status = .resolved
        alert.resolvedAt = Date()
        alert.resolvedByUserId = user.id
        alert.resolvedByName = user.name
        alert.correctiveAction = action

        log(
            restaurantId: alert.restaurantId,
            user: user,
            action: "CHECKLIST_ALERT_RESOLVED",
            entityId: alert.id,
            details: action,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func archiveRun(_ run: ChecklistRun, user: LocalUser, restaurantId: UUID, modelContext: ModelContext) throws {
        run.status = .archived
        run.isArchived = true
        log(
            restaurantId: restaurantId,
            user: user,
            action: "CHECKLIST_RUN_ARCHIVED",
            entityId: run.id,
            details: run.templateTitleSnapshot,
            modelContext: modelContext
        )
        try modelContext.save()
        syncChecklistNotifications(restaurantId: restaurantId, modelContext: modelContext)
    }

    func syncScheduledRuns(
        restaurantId: UUID,
        user: LocalUser?,
        modelContext: ModelContext,
        now: Date = Date()
    ) {
        let templates = ((try? modelContext.fetch(FetchDescriptor<ChecklistTemplate>())) ?? [])
            .filter { $0.restaurantId == restaurantId && $0.isActive && !$0.isSuggestedLibrary }
        let allRuns = (try? modelContext.fetch(FetchDescriptor<ChecklistRun>())) ?? []

        for template in templates {
            guard let dueForCycle = scheduleService.dueDateForCurrentCycle(
                frequency: template.frequency,
                scheduledHour: template.scheduledHour,
                scheduledMinute: template.scheduledMinute,
                anchorDate: template.createdAt,
                now: now
            ) else {
                continue
            }

            let templateRuns = allRuns
                .filter { $0.restaurantId == restaurantId && $0.templateId == template.id && !$0.isArchived }
                .sorted(by: { $0.createdAt > $1.createdAt })

            if let currentCycleRun = templateRuns.first(where: { run in
                guard let dueAt = run.dueAt else { return false }
                return scheduleService.isSameCycle(dueAt, dueForCycle, frequency: template.frequency)
            }) {
                if currentCycleRun.status != .completed && currentCycleRun.status != .failed && dueForCycle < now {
                    currentCycleRun.status = .overdue
                    createOverdueAlertIfNeeded(run: currentCycleRun, restaurantId: restaurantId, modelContext: modelContext)
                }
                continue
            }

            let newRun = ChecklistRun(
                restaurantId: restaurantId,
                templateId: template.id,
                templateTitleSnapshot: template.title,
                startedAt: now,
                dueAt: dueForCycle,
                status: dueForCycle < now ? .overdue : .notStarted
            )
            modelContext.insert(newRun)
            seedItemResults(for: newRun, templateId: template.id, modelContext: modelContext)
            if newRun.status == .overdue {
                createOverdueAlertIfNeeded(run: newRun, restaurantId: restaurantId, modelContext: modelContext)
            }
            if let user {
                log(
                    restaurantId: restaurantId,
                    user: user,
                    action: "CHECKLIST_RUN_SCHEDULED",
                    entityId: newRun.id,
                    details: template.title,
                    modelContext: modelContext
                )
            }
        }

        try? modelContext.save()
        syncChecklistNotifications(restaurantId: restaurantId, modelContext: modelContext, now: now)
    }

    func log(
        restaurantId: UUID,
        user: LocalUser,
        action: String,
        entityId: UUID,
        details: String?,
        modelContext: ModelContext
    ) {
        let log = ChecklistAuditLog(
            restaurantId: restaurantId,
            userId: user.id,
            userName: user.name,
            action: action,
            entityId: entityId,
            details: details
        )
        modelContext.insert(log)
    }

    private func seedItemResults(for run: ChecklistRun, templateId: UUID, modelContext: ModelContext) {
        let itemTemplates = (try? modelContext.fetch(FetchDescriptor<ChecklistItemTemplate>())) ?? []
        let scopedItems = itemTemplates
            .filter { $0.checklistTemplateId == templateId }
            .sorted(by: { $0.orderIndex < $1.orderIndex })

        for item in scopedItems {
            modelContext.insert(
                ChecklistItemResult(
                    checklistRunId: run.id,
                    itemTemplateId: item.id,
                    titleSnapshot: item.title,
                    result: .pending,
                    orderIndex: item.orderIndex
                )
            )
        }
    }

    private func createOverdueAlertIfNeeded(run: ChecklistRun, restaurantId: UUID, modelContext: ModelContext) {
        let alerts = (try? modelContext.fetch(FetchDescriptor<ChecklistAlert>())) ?? []
        let exists = alerts.contains {
            $0.checklistRunId == run.id && $0.isActive && $0.message.contains("in ritardo")
        }
        guard !exists else { return }
        modelContext.insert(
            ChecklistAlert(
                restaurantId: restaurantId,
                checklistRunId: run.id,
                severity: .high,
                message: "Checklist in ritardo: \(run.templateTitleSnapshot)"
            )
        )
    }

    private func syncChecklistNotifications(restaurantId: UUID, modelContext: ModelContext, now: Date = Date()) {
        let runs = ((try? modelContext.fetch(FetchDescriptor<ChecklistRun>())) ?? [])
            .filter { $0.restaurantId == restaurantId && !$0.isArchived }
        notificationService.syncNotifications(for: runs, now: now)
    }
}

struct ChecklistItemTemplateDraft: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var type: ChecklistItemType
    var isRequired: Bool
    var requiresNoteIfFailed: Bool
}

struct SuggestedChecklistTemplate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: ChecklistCategory
    let frequency: ChecklistFrequency
    let scheduledHour: Int?
    let scheduledMinute: Int?
    let items: [ChecklistItemTemplateDraft]
}

private extension ChecklistService {
    var defaultTemplateDefinitions: [SuggestedChecklistTemplate] {
        [
            .init(
                title: "Apertura cucina",
                description: "Controlli apertura turno cucina.",
                category: .opening,
                frequency: .daily,
                scheduledHour: 9,
                scheduledMinute: 0,
                items: [
                    .init(title: "Sapone e carta mani disponibili", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Superfici di lavoro pulite", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Frigoriferi in ordine", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Attrezzature pulite", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Rifiuti vuoti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Area preparazione pronta", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Chiusura cucina",
                description: "Controlli chiusura turno cucina.",
                category: .closing,
                frequency: .daily,
                scheduledHour: 23,
                scheduledMinute: 0,
                items: [
                    .init(title: "Piani sanificati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Pavimenti puliti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Rifiuti smaltiti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Alimenti coperti ed etichettati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Frigoriferi chiusi", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Attrezzature spente/pulite", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Pulizie giornaliere",
                description: "Pulizie operative quotidiane.",
                category: .cleaning,
                frequency: .daily,
                scheduledHour: 21,
                scheduledMinute: 0,
                items: [
                    .init(title: "Banco preparazione sanificato", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Lavelli puliti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Pavimenti lavati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Utensili lavati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Maniglie e superfici toccate sanificate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Igiene personale",
                description: "Controlli igiene personale staff.",
                category: .personalHygiene,
                frequency: .daily,
                scheduledHour: 10,
                scheduledMinute: 0,
                items: [
                    .init(title: "Mani lavate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Divisa pulita", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Capelli coperti se necessario", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Guanti disponibili", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Nessun oggetto personale in zona preparazione", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Conservazione alimenti",
                description: "Controlli conservazione e stoccaggio.",
                category: .foodStorage,
                frequency: .daily,
                scheduledHour: 12,
                scheduledMinute: 0,
                items: [
                    .init(title: "Prodotti coperti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Crudo e cotto separati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Scadenze visibili", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Etichette leggibili", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Nessun prodotto scaduto", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Controllo scadenze visibili",
                description: "Verifica giornaliera scadenze e rotazione prodotti.",
                category: .foodStorage,
                frequency: .daily,
                scheduledHour: 18,
                scheduledMinute: 0,
                items: [
                    .init(title: "Scadenze del giorno verificate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti in scadenza separati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Aggiornata rotazione FIFO", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti scaduti rimossi", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Allergeni",
                description: "Controlli prevenzione allergeni.",
                category: .allergens,
                frequency: .weekly,
                scheduledHour: 13,
                scheduledMinute: 0,
                items: [
                    .init(title: "Allergeni separati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Utensili dedicati/puliti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Contaminazione crociata evitata", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Ingredienti allergeni identificati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Ricevimento merci",
                description: "Controlli ingresso merci.",
                category: .receivingGoods,
                frequency: .daily,
                scheduledHour: 8,
                scheduledMinute: 30,
                items: [
                    .init(title: "Imballi integri", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti controllati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Temperature verificate se necessario", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Lotti/documenti presenti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti non conformi separati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Rifiuti",
                description: "Controlli gestione rifiuti.",
                category: .waste,
                frequency: .daily,
                scheduledHour: 17,
                scheduledMinute: 0,
                items: [
                    .init(title: "Bidoni non pieni", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Sacchi sostituiti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Area rifiuti pulita", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Differenziata rispettata", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Attrezzature",
                description: "Controlli stato e pulizia attrezzature.",
                category: .equipment,
                frequency: .weekly,
                scheduledHour: 15,
                scheduledMinute: 0,
                items: [
                    .init(title: "Forni/piastre puliti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Frigoriferi funzionanti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Abbattitore pulito", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Utensili integri", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Nessuna attrezzatura danneggiata", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Verifica settimanale HACCP",
                description: "Controlli di conformita settimanali del piano HACCP.",
                category: .custom,
                frequency: .weekly,
                scheduledHour: 11,
                scheduledMinute: 0,
                items: [
                    .init(title: "Procedure compilate correttamente", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Azioni correttive chiuse", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Tracciabilita lotti aggiornata", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Pulizia profonda settimanale",
                description: "Pulizia approfondita aree critiche e zone meno accessibili.",
                category: .cleaning,
                frequency: .weekly,
                scheduledHour: 20,
                scheduledMinute: 0,
                items: [
                    .init(title: "Pulizia cappe e filtri", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Pulizia retro attrezzature", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Sanificazione celle frigo interne", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Pulizia profonda frigoriferi",
                description: "Pulizia completa frigoriferi e guarnizioni.",
                category: .cleaning,
                frequency: .weekly,
                scheduledHour: 19,
                scheduledMinute: 0,
                items: [
                    .init(title: "Ripiani frigoriferi puliti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Guarnizioni sanificate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Scolo condensa controllato", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Sanificazione scaffali",
                description: "Sanificazione completa scaffalature cucina e magazzino.",
                category: .cleaning,
                frequency: .weekly,
                scheduledHour: 18,
                scheduledMinute: 30,
                items: [
                    .init(title: "Scaffali area cucina sanificati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Scaffali magazzino sanificati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti riposizionati correttamente", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Verifica stato utensili",
                description: "Controllo integrita utensili e sostituzione danneggiati.",
                category: .equipment,
                frequency: .weekly,
                scheduledHour: 16,
                scheduledMinute: 30,
                items: [
                    .init(title: "Coltelli integri e affilati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Taglieri non danneggiati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Utensili rotti rimossi", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Controllo aree magazzino",
                description: "Verifica ordine, pulizia e corretta segregazione magazzino.",
                category: .foodStorage,
                frequency: .weekly,
                scheduledHour: 17,
                scheduledMinute: 30,
                items: [
                    .init(title: "Area magazzino pulita", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti separati per categoria", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Nessun imballo danneggiato", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Controllo prodotti secchi",
                description: "Verifica settimanale prodotti secchi, integrita confezioni e scadenze.",
                category: .foodStorage,
                frequency: .weekly,
                scheduledHour: 12,
                scheduledMinute: 30,
                items: [
                    .init(title: "Confezioni integre", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Scadenze prodotti secchi verificate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti aperti etichettati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Controllo scadenze settimanale",
                description: "Controllo esteso FIFO e scadenze di tutti i reparti.",
                category: .foodStorage,
                frequency: .weekly,
                scheduledHour: 16,
                scheduledMinute: 0,
                items: [
                    .init(title: "FIFO rispettato in tutti i reparti", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti prossimi a scadenza segregati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Etichette leggibili e complete", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Manutenzione mensile attrezzature",
                description: "Check funzionale e sicurezza attrezzature principali.",
                category: .equipment,
                frequency: .monthly,
                scheduledHour: 10,
                scheduledMinute: 30,
                items: [
                    .init(title: "Forni e piastre verificati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Frigoriferi con guarnizioni integre", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Abbattitore verificato", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Scheda manutenzione aggiornata", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Audit mensile allergeni ed etichette",
                description: "Verifica documentale e operativa allergeni.",
                category: .allergens,
                frequency: .monthly,
                scheduledHour: 14,
                scheduledMinute: 0,
                items: [
                    .init(title: "Matrice allergeni aggiornata", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Etichette ingredienti complete", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Procedure anti-contaminazione confermate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Verifica generale HACCP",
                description: "Revisione mensile completa dell'applicazione HACCP.",
                category: .custom,
                frequency: .monthly,
                scheduledHour: 10,
                scheduledMinute: 0,
                items: [
                    .init(title: "Punti critici monitorati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Registri HACCP completi", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Azioni correttive tracciate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Controllo documentazione",
                description: "Controllo mensile documentazione obbligatoria e registri.",
                category: .custom,
                frequency: .monthly,
                scheduledHour: 11,
                scheduledMinute: 0,
                items: [
                    .init(title: "Manuale HACCP aggiornato", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Schede controllo archiviate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Documentazione fornitori disponibile", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Revisione procedure pulizia",
                description: "Revisione mensile procedure pulizia e sanificazione.",
                category: .cleaning,
                frequency: .monthly,
                scheduledHour: 15,
                scheduledMinute: 0,
                items: [
                    .init(title: "Procedure pulizia aggiornate", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Prodotti sanificanti conformi", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Piano interventi straordinari definito", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            ),
            .init(
                title: "Verifica formazione personale",
                description: "Verifica mensile formazione e aggiornamento staff su procedure.",
                category: .personalHygiene,
                frequency: .monthly,
                scheduledHour: 16,
                scheduledMinute: 0,
                items: [
                    .init(title: "Nuovi ingressi formati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Richiami formativi registrati", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true),
                    .init(title: "Procedure HACCP comprese dal team", description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
                ]
            )
        ]
    }
}
