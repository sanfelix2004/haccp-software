import Foundation
import SwiftData

enum ChecklistServiceError: LocalizedError {
    case noteRequiredForFailure
    case missingItemResults

    var errorDescription: String? {
        switch self {
        case .noteRequiredForFailure:
            return "Per segnare NON OK devi descrivere la criticità."
        case .missingItemResults:
            return "Impossibile completare il task: voci non trovate nel registro."
        }
    }
}

@MainActor
final class ChecklistService {
    private let validationService = ChecklistValidationService()
    private let scheduleService = ChecklistScheduleService()
    private let notificationService = ChecklistNotificationService()
    private let periodicEngine = PeriodicTaskEngine()

    func createTemplate(
        restaurantId: UUID,
        title: String,
        description: String,
        category: ChecklistCategory,
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        scheduleWeekday: Int? = nil,
        scheduleDayOfMonth: Int? = nil,
        scheduleMonth: Int? = nil,
        allowsBulkPass: Bool = true,
        bulkPassTitle: String? = nil,
        areaTag: String? = nil,
        customScheduleIntervalDays: Int? = nil,
        sourceCleaningTaskId: UUID? = nil,
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
            scheduleWeekday: scheduleWeekday,
            scheduleDayOfMonth: scheduleDayOfMonth,
            scheduleMonth: scheduleMonth,
            allowsBulkPass: allowsBulkPass,
            bulkPassTitle: bulkPassTitle,
            areaTag: areaTag,
            customScheduleIntervalDays: customScheduleIntervalDays,
            sourceCleaningTaskId: sourceCleaningTaskId,
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

    func createCleaningBridgeTemplate(
        task: CleaningTask,
        createdBy: LocalUser,
        modelContext: ModelContext
    ) throws -> ChecklistTemplate {
        let title = "\(task.areaNameSnapshot) · \(task.title)"
        return try createTemplate(
            restaurantId: task.restaurantId,
            title: title,
            description: "Registro HACCP collegato al task di pulizia",
            category: .cleaning,
            frequency: task.frequency.checklistFrequency,
            scheduledHour: 23,
            scheduledMinute: 59,
            allowsBulkPass: false,
            areaTag: task.areaNameSnapshot,
            customScheduleIntervalDays: task.frequency == .personalizzato ? task.customIntervalDays : nil,
            sourceCleaningTaskId: task.id,
            createdBy: createdBy,
            items: [
                ChecklistItemTemplateDraft(
                    title: task.title,
                    description: "Esito sanificazione \(task.areaNameSnapshot)",
                    type: .passFail,
                    isRequired: true,
                    requiresNoteIfFailed: true
                )
            ],
            modelContext: modelContext
        )
    }

    func createQuickTaskTemplate(
        restaurantId: UUID,
        title: String,
        description: String,
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        createdBy: LocalUser,
        modelContext: ModelContext
    ) throws -> ChecklistTemplate {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return try createTemplate(
            restaurantId: restaurantId,
            title: trimmedTitle,
            description: trimmedDescription.isEmpty ? "Attività rapida ricorrente" : trimmedDescription,
            category: .quickTask,
            frequency: frequency,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            createdBy: createdBy,
            items: [
                ChecklistItemTemplateDraft(
                    title: trimmedTitle,
                    description: trimmedDescription,
                    type: .doneNotDone,
                    isRequired: true,
                    requiresNoteIfFailed: false
                )
            ],
            modelContext: modelContext
        )
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
            scheduleWeekday: suggestedTemplate.scheduleWeekday,
            scheduleDayOfMonth: suggestedTemplate.scheduleDayOfMonth,
            scheduleMonth: suggestedTemplate.scheduleMonth,
            allowsBulkPass: suggestedTemplate.allowsBulkPass,
            bulkPassTitle: suggestedTemplate.bulkPassTitle,
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

        for def in ChecklistDefaultTemplates.definitions {
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
                scheduleWeekday: def.scheduleWeekday,
                scheduleDayOfMonth: def.scheduleDayOfMonth,
                scheduleMonth: def.scheduleMonth,
                allowsBulkPass: def.allowsBulkPass,
                bulkPassTitle: def.bulkPassTitle,
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
                scheduleWeekday: template.scheduleWeekday,
                scheduleDayOfMonth: template.scheduleDayOfMonth,
                scheduleMonth: template.scheduleMonth,
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
        modelContext: ModelContext,
        requiresNoteIfFailed: Bool? = nil
    ) throws {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let requiresNote = requiresNoteIfFailed
            ?? itemTemplate(for: itemResult.itemTemplateId, modelContext: modelContext)?.requiresNoteIfFailed
            ?? true

        if result == .fail, requiresNote, trimmedNote.isEmpty {
            throw ChecklistServiceError.noteRequiredForFailure
        }

        let previousResult = itemResult.result
        itemResult.result = result
        itemResult.note = trimmedNote.isEmpty ? nil : trimmedNote
        itemResult.completedAt = Date()
        itemResult.completedByUserId = user.id

        let scopedResults = itemResults(for: run.id, modelContext: modelContext)
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
            if run.status == .completed || run.status == .failed {
                deactivateOverdueAlerts(for: run, modelContext: modelContext)
            }
        }

        if result == .fail {
            upsertFailureAlert(
                itemResult: itemResult,
                note: trimmedNote,
                run: run,
                restaurantId: restaurantId,
                user: user,
                modelContext: modelContext
            )
        } else if previousResult == .fail {
            autoResolveFailureAlert(
                itemResult: itemResult,
                run: run,
                user: user,
                modelContext: modelContext
            )
        }

        guard modelContext.saveSafely(operation: "checklist-item-result") else {
            throw SwiftDataOperationError.saveFailed("checklist-item-result")
        }
    }

    /// Completamento inline pulizie: un tap segna l'unica voce come OK e chiude il run.
    func inlineCompleteCleaningRun(
        run: ChecklistRun,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws {
        var results = itemResults(for: run.id, modelContext: modelContext)

        if results.isEmpty {
            seedItemResults(for: run, templateId: run.templateId, modelContext: modelContext)
            try modelContext.save()
            results = itemResults(for: run.id, modelContext: modelContext)
        }

        guard let itemResult = results.first else {
            throw ChecklistServiceError.missingItemResults
        }

        if run.status == .notStarted || run.status == .overdue {
            run.status = .inProgress
        }

        try updateItemResult(
            itemResult: itemResult,
            result: .pass,
            note: nil,
            user: user,
            run: run,
            restaurantId: restaurantId,
            modelContext: modelContext
        )
    }

    /// Completamento bulk pulizie per macro area: segna tutti i task aperti nell'elenco.
    @discardableResult
    func completeAllCleaningRuns(
        runs: [ChecklistRun],
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws -> Int {
        var count = 0
        for run in runs where run.status != .completed {
            try inlineCompleteCleaningRun(
                run: run,
                user: user,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
            count += 1
        }
        return count
    }

    /// Completamento bulk checklist operative per macro area (tutte le voci OK).
    @discardableResult
    func completeAllChecklistRuns(
        runs: [ChecklistRun],
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws -> Int {
        var count = 0
        for run in runs where run.status != .completed && run.status != .failed {
            if itemResults(for: run.id, modelContext: modelContext).isEmpty {
                seedItemResults(for: run, templateId: run.templateId, modelContext: modelContext)
            }
            guard run.progressPercentage < 100 else { continue }
            try markAllItemsPass(
                run: run,
                user: user,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
            count += 1
        }
        return count
    }

    private func itemResults(for runId: UUID, modelContext: ModelContext) -> [ChecklistItemResult] {
        var descriptor = FetchDescriptor<ChecklistItemResult>(
            predicate: #Predicate { $0.checklistRunId == runId },
            sortBy: [SortDescriptor(\ChecklistItemResult.orderIndex)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func itemTemplate(for id: UUID, modelContext: ModelContext) -> ChecklistItemTemplate? {
        var descriptor = FetchDescriptor<ChecklistItemTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func activeAlerts(for runId: UUID, modelContext: ModelContext) -> [ChecklistAlert] {
        var descriptor = FetchDescriptor<ChecklistAlert>(
            predicate: #Predicate { $0.checklistRunId == runId && $0.isActive }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func upsertFailureAlert(
        itemResult: ChecklistItemResult,
        note: String,
        run: ChecklistRun,
        restaurantId: UUID,
        user: LocalUser,
        modelContext: ModelContext
    ) {
        let alerts = activeAlerts(for: run.id, modelContext: modelContext)
        let message = failureAlertMessage(title: itemResult.titleSnapshot, note: note)
        if let existing = alerts.first(where: {
            $0.checklistRunId == run.id
            && $0.isActive
            && ($0.itemResultId == itemResult.id || matchesLegacyFailureAlert($0, itemResult: itemResult))
        }) {
            existing.message = message
            existing.itemResultId = itemResult.id
            return
        }

        let alert = ChecklistAlert(
            restaurantId: restaurantId,
            checklistRunId: run.id,
            itemResultId: itemResult.id,
            severity: .high,
            message: message
        )
        modelContext.insert(alert)
        log(
            restaurantId: restaurantId,
            user: user,
            action: "CHECKLIST_ITEM_FAILED",
            entityId: itemResult.id,
            details: itemResult.titleSnapshot,
            modelContext: modelContext
        )
    }

    private func autoResolveFailureAlert(
        itemResult: ChecklistItemResult,
        run: ChecklistRun,
        user: LocalUser,
        modelContext: ModelContext
    ) {
        let alerts = activeAlerts(for: run.id, modelContext: modelContext)
        for alert in alerts {
            guard alert.itemResultId == itemResult.id || matchesLegacyFailureAlert(alert, itemResult: itemResult) else {
                continue
            }
            alert.isActive = false
            alert.status = .resolved
            alert.resolvedAt = Date()
            alert.resolvedByUserId = user.id
            alert.resolvedByName = user.name
            alert.correctiveAction = "Voce ripristinata durante la compilazione"
        }
    }

    private func failureAlertMessage(title: String, note: String) -> String {
        if note.isEmpty {
            return "NON OK · \(title)"
        }
        return "NON OK · \(title) · \(note)"
    }

    private func matchesLegacyFailureAlert(_ alert: ChecklistAlert, itemResult: ChecklistItemResult) -> Bool {
        alert.itemResultId == nil && alert.message.contains(itemResult.titleSnapshot)
    }

    func markAllItemsPass(
        run: ChecklistRun,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws {
        let results = itemResults(for: run.id, modelContext: modelContext)

        let now = Date()
        for itemResult in results where itemResult.result != .pass {
            itemResult.result = .pass
            itemResult.note = nil
            itemResult.completedAt = now
            itemResult.completedByUserId = user.id
        }

        let completedCount = results.filter { $0.result != .pending }.count
        run.progressPercentage = results.isEmpty ? 0 : (Double(completedCount) / Double(results.count)) * 100
        run.status = .completed
        run.completedAt = now
        run.completedByUserId = user.id
        run.completedByNameSnapshot = user.name
        deactivateOverdueAlerts(for: run, modelContext: modelContext)

        log(
            restaurantId: restaurantId,
            user: user,
            action: "CHECKLIST_BULK_PASS",
            entityId: run.id,
            details: run.templateTitleSnapshot,
            modelContext: modelContext
        )
        guard modelContext.saveSafely(operation: "checklist-bulk-pass") else {
            throw SwiftDataOperationError.saveFailed("checklist-bulk-pass")
        }
        syncChecklistNotifications(restaurantId: restaurantId, modelContext: modelContext)
    }

    func updateTemplate(
        _ template: ChecklistTemplate,
        title: String,
        description: String,
        category: ChecklistCategory,
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        scheduleWeekday: Int?,
        scheduleDayOfMonth: Int?,
        scheduleMonth: Int?,
        allowsBulkPass: Bool,
        bulkPassTitle: String?,
        areaTag: String? = nil,
        isActive: Bool,
        items: [ChecklistItemTemplateDraft],
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        template.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        template.checklistDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        template.category = category
        template.frequency = frequency
        template.scheduledHour = scheduledHour
        template.scheduledMinute = scheduledMinute
        template.scheduleWeekday = scheduleWeekday
        template.scheduleDayOfMonth = scheduleDayOfMonth
        template.scheduleMonth = scheduleMonth
        template.allowsBulkPass = allowsBulkPass
        template.bulkPassTitle = bulkPassTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? bulkPassTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        template.isActive = isActive
        template.updatedAt = Date()
        if !template.isCleaningBridge {
            let trimmedArea = areaTag?.trimmingCharacters(in: .whitespacesAndNewlines)
            template.areaTag = trimmedArea?.isEmpty == false ? trimmedArea : nil
        }

        let existing = ((try? modelContext.fetch(FetchDescriptor<ChecklistItemTemplate>())) ?? [])
            .filter { $0.checklistTemplateId == template.id }
        for item in existing { modelContext.delete(item) }

        for (index, draft) in items.enumerated() {
            modelContext.insert(
                ChecklistItemTemplate(
                    checklistTemplateId: template.id,
                    title: draft.title,
                    itemDescription: draft.description,
                    type: draft.type,
                    isRequired: draft.isRequired,
                    orderIndex: index,
                    requiresNoteIfFailed: draft.requiresNoteIfFailed
                )
            )
        }

        log(
            restaurantId: template.restaurantId,
            user: user,
            action: "CHECKLIST_TEMPLATE_UPDATED",
            entityId: template.id,
            details: template.title,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func deleteTemplate(
        _ template: ChecklistTemplate,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        let runs = ((try? modelContext.fetch(FetchDescriptor<ChecklistRun>())) ?? [])
            .filter { $0.templateId == template.id }
        let results = (try? modelContext.fetch(FetchDescriptor<ChecklistItemResult>())) ?? []
        let alerts = (try? modelContext.fetch(FetchDescriptor<ChecklistAlert>())) ?? []
        let items = ((try? modelContext.fetch(FetchDescriptor<ChecklistItemTemplate>())) ?? [])
            .filter { $0.checklistTemplateId == template.id }

        for run in runs {
            for result in results where result.checklistRunId == run.id {
                modelContext.delete(result)
            }
            for alert in alerts where alert.checklistRunId == run.id {
                modelContext.delete(alert)
            }
            modelContext.delete(run)
        }
        for item in items { modelContext.delete(item) }

        log(
            restaurantId: template.restaurantId,
            user: user,
            action: "CHECKLIST_TEMPLATE_DELETED",
            entityId: template.id,
            details: template.title,
            modelContext: modelContext
        )
        modelContext.delete(template)
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
        deactivateOverdueAlerts(for: run, modelContext: modelContext)

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
        KitchenProcessNotifications.postRecordsDidChange()
    }

    func archiveRun(_ run: ChecklistRun, user: LocalUser, restaurantId: UUID, modelContext: ModelContext) throws {
        run.status = .archived
        run.isArchived = true
        deactivateOverdueAlerts(for: run, modelContext: modelContext)
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
        onlyCleaningBridge: Bool = false,
        now: Date = Date()
    ) {
        let rid = restaurantId
        var templateDescriptor = FetchDescriptor<ChecklistTemplate>(
            predicate: #Predicate {
                $0.restaurantId == rid && $0.isActive && !$0.isSuggestedLibrary
            },
            sortBy: [SortDescriptor(\ChecklistTemplate.title)]
        )
        templateDescriptor.fetchLimit = PerformanceConfig.checklistTemplateFetchLimit
        var templates = (try? modelContext.fetch(templateDescriptor)) ?? []
        if onlyCleaningBridge {
            templates = templates.filter { $0.isCleaningBridge || $0.category == .cleaning }
        }

        var runDescriptor = FetchDescriptor<ChecklistRun>(
            predicate: #Predicate { $0.restaurantId == rid && !$0.isArchived },
            sortBy: [SortDescriptor(\ChecklistRun.createdAt, order: .reverse)]
        )
        runDescriptor.fetchLimit = PerformanceConfig.checklistRunFetchLimit
        let allRuns = (try? modelContext.fetch(runDescriptor)) ?? []

        for template in templates {
            guard let dueForCycle = dueDateForTemplateCycle(template: template, now: now) else {
                continue
            }

            let frequencyKind = template.schedulingFrequencyKind
            guard shouldMaterializeTemplate(template, dueDate: dueForCycle, now: now) else {
                continue
            }

            let templateRuns = allRuns
                .filter { $0.restaurantId == restaurantId && $0.templateId == template.id && !$0.isArchived }
                .sorted(by: { $0.createdAt > $1.createdAt })

            closeStaleRuns(
                template: template,
                templateRuns: templateRuns,
                dueForCycle: dueForCycle,
                frequencyKind: frequencyKind,
                now: now,
                modelContext: modelContext
            )

            if let currentCycleRun = templateRuns.first(where: { run in
                guard let dueAt = run.dueAt else { return false }
                return periodicEngine.isSameCycle(dueAt, dueForCycle, frequency: frequencyKind)
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

    private func closeStaleRuns(
        template: ChecklistTemplate,
        templateRuns: [ChecklistRun],
        dueForCycle: Date,
        frequencyKind: PeriodicFrequencyKind,
        now: Date,
        modelContext: ModelContext
    ) {
        for run in templateRuns where isOpenRun(run) {
            guard let dueAt = run.dueAt else { continue }
            guard !periodicEngine.isSameCycle(dueAt, dueForCycle, frequency: frequencyKind) else { continue }
            run.status = .missed
            run.completedAt = now
            deactivateOverdueAlerts(for: run, modelContext: modelContext)
        }
    }

    private func isOpenRun(_ run: ChecklistRun) -> Bool {
        switch run.status {
        case .notStarted, .inProgress, .overdue: return true
        case .completed, .failed, .missed, .archived: return false
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

    /// Chiude automaticamente gli avvisi «in ritardo» quando la checklist non è più aperta.
    private func deactivateOverdueAlerts(for run: ChecklistRun, modelContext: ModelContext) {
        let alerts = activeAlerts(for: run.id, modelContext: modelContext)
        let now = Date()
        for alert in alerts where alert.message.contains("in ritardo") {
            alert.isActive = false
            alert.status = .resolved
            alert.resolvedAt = now
            alert.correctiveAction = "Checklist chiusa"
        }
    }

    private func syncChecklistNotifications(restaurantId: UUID, modelContext: ModelContext, now: Date = Date()) {
        let runs = ((try? modelContext.fetch(FetchDescriptor<ChecklistRun>())) ?? [])
            .filter { $0.restaurantId == restaurantId && !$0.isArchived }
        notificationService.syncNotifications(for: runs, now: now)
        KitchenProcessNotifications.postRecordsDidChange()
    }

    private func dueDateForTemplateCycle(template: ChecklistTemplate, now: Date) -> Date? {
        if template.frequency == .custom {
            let days = max(template.customScheduleIntervalDays ?? 1, 1)
            let interval = periodicEngine.periodInterval(
                for: .personalizzato,
                customIntervalDays: days,
                reference: now
            )
            return interval.end.addingTimeInterval(-1)
        }
        return scheduleService.dueDateForCurrentCycle(
            frequency: template.frequency,
            scheduledHour: template.scheduledHour,
            scheduledMinute: template.scheduledMinute,
            scheduleWeekday: template.scheduleWeekday,
            scheduleDayOfMonth: template.scheduleDayOfMonth,
            scheduleMonth: template.scheduleMonth,
            anchorDate: template.createdAt,
            now: now
        )
    }

    private func shouldMaterializeTemplate(
        _ template: ChecklistTemplate,
        dueDate: Date,
        now: Date
    ) -> Bool {
        if template.frequency == .custom {
            return true
        }
        return scheduleService.shouldMaterializeRun(
            frequency: template.frequency,
            dueDate: dueDate,
            now: now
        )
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
    let scheduleWeekday: Int?
    let scheduleDayOfMonth: Int?
    let scheduleMonth: Int?
    let allowsBulkPass: Bool
    let bulkPassTitle: String?
    let items: [ChecklistItemTemplateDraft]

    init(
        title: String,
        description: String,
        category: ChecklistCategory,
        frequency: ChecklistFrequency,
        scheduledHour: Int?,
        scheduledMinute: Int?,
        scheduleWeekday: Int? = nil,
        scheduleDayOfMonth: Int? = nil,
        scheduleMonth: Int? = nil,
        allowsBulkPass: Bool = true,
        bulkPassTitle: String? = nil,
        items: [ChecklistItemTemplateDraft]
    ) {
        self.title = title
        self.description = description
        self.category = category
        self.frequency = frequency
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.scheduleWeekday = scheduleWeekday
        self.scheduleDayOfMonth = scheduleDayOfMonth
        self.scheduleMonth = scheduleMonth
        self.allowsBulkPass = allowsBulkPass
        self.bulkPassTitle = bulkPassTitle
        self.items = items
    }
}
