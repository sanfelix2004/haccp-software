import Foundation
import SwiftData

/// BFF pulizie: UI veloce in cucina, persistenza sul motore checklist.
@MainActor
struct CleaningTaskBFF {
    private let checklistService = ChecklistService()
    private let engine = PeriodicTaskEngine()

    func ensureBridgeTemplates(
        restaurantId: UUID,
        tasks: [CleaningTask],
        user: LocalUser,
        modelContext: ModelContext
    ) {
        for task in tasks where task.restaurantId == restaurantId && task.isActive {
            try? ensureBridgeTemplate(task: task, user: user, modelContext: modelContext, persistImmediately: false)
        }
        modelContext.saveSafely(operation: "cleaning-bridge-templates")
    }

    @discardableResult
    func ensureBridgeTemplate(
        task: CleaningTask,
        user: LocalUser,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> ChecklistTemplate {
        if let templateId = task.linkedChecklistTemplateId,
           let existing = fetchTemplate(id: templateId, modelContext: modelContext) {
            syncBridgeTemplate(from: task, template: existing)
            if persistImmediately {
                modelContext.saveSafely(operation: "cleaning-bridge-template")
            }
            return existing
        }

        let rid = task.restaurantId
        var descriptor = FetchDescriptor<ChecklistTemplate>(
            predicate: #Predicate { $0.restaurantId == rid }
        )
        descriptor.fetchLimit = PerformanceConfig.checklistTemplateFetchLimit
        let templates = (try? modelContext.fetch(descriptor)) ?? []
        if let existing = templates.first(where: { $0.sourceCleaningTaskId == task.id }) {
            task.linkedChecklistTemplateId = existing.id
            syncBridgeTemplate(from: task, template: existing)
            if persistImmediately {
                modelContext.saveSafely(operation: "cleaning-bridge-template")
            }
            return existing
        }

        let template = try checklistService.createCleaningBridgeTemplate(
            task: task,
            createdBy: user,
            modelContext: modelContext
        )
        task.linkedChecklistTemplateId = template.id
        if persistImmediately {
            try modelContext.save()
        }
        return template
    }

    func syncOutcome(
        task: CleaningTask,
        record: CleaningRecord,
        outcome: CleaningTaskOutcome,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        guard outcome != .nonFatto else { return }

        let template = try ensureBridgeTemplate(task: task, user: user, modelContext: modelContext)
        let (run, itemResult) = try ensureBridgeRun(
            template: template,
            record: record,
            user: user,
            modelContext: modelContext
        )

        let mapped: ChecklistItemResultValue
        let note: String?
        switch outcome {
        case .pulito:
            mapped = .pass
            note = record.notes
        case .nonPulito:
            mapped = .fail
            note = [record.notes, record.correctiveAction]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            let finalNote = note?.isEmpty == false ? note : "Non pulito"
            try checklistService.updateItemResult(
                itemResult: itemResult,
                result: .fail,
                note: finalNote,
                user: user,
                run: run,
                restaurantId: record.restaurantId,
                modelContext: modelContext
            )
            return
        case .nonApplicabile:
            mapped = .notApplicable
            note = record.notes
        case .daFare:
            mapped = .pending
            note = nil
        case .nonFatto:
            return
        }

        try checklistService.updateItemResult(
            itemResult: itemResult,
            result: mapped,
            note: note,
            user: user,
            run: run,
            restaurantId: record.restaurantId,
            modelContext: modelContext
        )
    }

    private func ensureBridgeRun(
        template: ChecklistTemplate,
        record: CleaningRecord,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> (ChecklistRun, ChecklistItemResult) {
        let allRuns = ((try? modelContext.fetch(FetchDescriptor<ChecklistRun>())) ?? [])
            .filter { $0.restaurantId == record.restaurantId && $0.templateId == template.id && !$0.isArchived }
        let dueAt = record.periodEnd.addingTimeInterval(-1)

        if let existing = allRuns.first(where: { run in
            guard let runDue = run.dueAt else { return false }
            return engine.isSameCycle(runDue, record.periodStart, frequency: record.frequency.periodicKind)
        }) {
            let results = ((try? modelContext.fetch(FetchDescriptor<ChecklistItemResult>())) ?? [])
                .filter { $0.checklistRunId == existing.id }
                .sorted(by: { $0.orderIndex < $1.orderIndex })
            if let first = results.first {
                return (existing, first)
            }
        }

        let run = ChecklistRun(
            restaurantId: record.restaurantId,
            templateId: template.id,
            templateTitleSnapshot: template.title,
            startedAt: Date(),
            dueAt: dueAt,
            status: .inProgress
        )
        modelContext.insert(run)

        let itemTemplates = ((try? modelContext.fetch(FetchDescriptor<ChecklistItemTemplate>())) ?? [])
            .filter { $0.checklistTemplateId == template.id }
            .sorted(by: { $0.orderIndex < $1.orderIndex })

        guard let itemTemplate = itemTemplates.first else {
            throw CleaningTaskBFFError.missingBridgeItem
        }

        let itemResult = ChecklistItemResult(
            checklistRunId: run.id,
            itemTemplateId: itemTemplate.id,
            titleSnapshot: itemTemplate.title,
            result: .pending,
            orderIndex: itemTemplate.orderIndex
        )
        modelContext.insert(itemResult)
        try modelContext.save()
        return (run, itemResult)
    }

    private func fetchTemplate(id: UUID, modelContext: ModelContext) -> ChecklistTemplate? {
        let templates = (try? modelContext.fetch(FetchDescriptor<ChecklistTemplate>())) ?? []
        return templates.first(where: { $0.id == id })
    }

    private func syncBridgeTemplate(from task: CleaningTask, template: ChecklistTemplate) {
        template.areaTag = task.areaNameSnapshot
        template.frequency = task.frequency.checklistFrequency
        template.customScheduleIntervalDays = task.frequency == .personalizzato ? task.customIntervalDays : nil
        template.title = "\(task.areaNameSnapshot) · \(task.title)"
        template.isActive = task.isActive
        template.updatedAt = Date()
    }
}

enum CleaningTaskBFFError: LocalizedError {
    case missingBridgeItem

    var errorDescription: String? {
        switch self {
        case .missingBridgeItem:
            return "Modello checklist collegato non valido."
        }
    }
}
