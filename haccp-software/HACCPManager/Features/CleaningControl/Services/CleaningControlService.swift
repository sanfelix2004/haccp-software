import Foundation
import SwiftData

struct CleaningTaskCard: Identifiable {
    let id: UUID
    let areaName: String
    let taskName: String
    let frequency: CleaningTaskFrequency
    let customIntervalDays: Int?
    let dueDate: Date
    let isOverdue: Bool
    let isCompleted: Bool
    let record: CleaningRecord
}

struct CleaningSummary {
    let completed: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

struct CleaningControlService {
    private let engine = PeriodicTaskEngine()

    private struct SeedTask {
        let title: String
        let frequency: CleaningTaskFrequency
    }

    private static let seedData: [(area: String, tasks: [SeedTask])] = [
        ("Cucina", [
            SeedTask(title: "Pulizia superfici generali", frequency: .giornaliero),
            SeedTask(title: "Sanificazione area preparazione", frequency: .giornaliero),
            SeedTask(title: "Pulizia profonda angoli e basi", frequency: .settimanale)
        ]),
        ("Piano lavoro", [
            SeedTask(title: "Pulizia superfici", frequency: .giornaliero),
            SeedTask(title: "Sanificazione", frequency: .giornaliero),
            SeedTask(title: "Controllo residui alimentari", frequency: .giornaliero)
        ]),
        ("Lavelli", [
            SeedTask(title: "Pulizia vasche", frequency: .giornaliero),
            SeedTask(title: "Sanificazione rubinetteria", frequency: .giornaliero),
            SeedTask(title: "Disincrostazione scarichi", frequency: .settimanale)
        ]),
        ("Frigoriferi", [
            SeedTask(title: "Rimozione sporco visibile", frequency: .giornaliero),
            SeedTask(title: "Pulizia ripiani", frequency: .settimanale),
            SeedTask(title: "Controllo guarnizioni", frequency: .settimanale),
            SeedTask(title: "Sanificazione completa interna", frequency: .mensile)
        ]),
        ("Freezer", [
            SeedTask(title: "Rimozione sporco visibile", frequency: .giornaliero),
            SeedTask(title: "Pulizia ripiani", frequency: .settimanale),
            SeedTask(title: "Controllo guarnizioni", frequency: .settimanale),
            SeedTask(title: "Rimozione ghiaccio anomalo", frequency: .mensile)
        ]),
        ("Forni", [
            SeedTask(title: "Pulizia camera forno", frequency: .giornaliero),
            SeedTask(title: "Rimozione grasso", frequency: .settimanale),
            SeedTask(title: "Pulizia tecnica profonda", frequency: .mensile)
        ]),
        ("Friggitrice", [
            SeedTask(title: "Pulizia esterna", frequency: .giornaliero),
            SeedTask(title: "Rimozione residui cestelli", frequency: .giornaliero),
            SeedTask(title: "Sanificazione maniglie", frequency: .settimanale)
        ]),
        ("Utensili", [
            SeedTask(title: "Lavaggio", frequency: .giornaliero),
            SeedTask(title: "Sanificazione", frequency: .giornaliero),
            SeedTask(title: "Asciugatura corretta", frequency: .giornaliero)
        ]),
        ("Pavimenti", [
            SeedTask(title: "Lavaggio", frequency: .giornaliero),
            SeedTask(title: "Sanificazione", frequency: .giornaliero),
            SeedTask(title: "Controllo zone critiche", frequency: .settimanale)
        ]),
        ("Magazzino", [
            SeedTask(title: "Ordine area", frequency: .giornaliero),
            SeedTask(title: "Pulizia scaffali", frequency: .settimanale),
            SeedTask(title: "Rimozione polvere completa", frequency: .mensile)
        ]),
        ("Area rifiuti", [
            SeedTask(title: "Pulizia contenitori", frequency: .giornaliero),
            SeedTask(title: "Sanificazione area", frequency: .giornaliero),
            SeedTask(title: "Controllo smaltimento corretto", frequency: .giornaliero)
        ])
    ]

    func ensureInitialTemplates(
        restaurantId: UUID,
        user: LocalUser,
        existingAreas: [CleaningArea],
        existingTasks: [CleaningTask],
        modelContext: ModelContext
    ) {
        if !existingAreas.filter({ $0.restaurantId == restaurantId }).isEmpty { return }

        var createdAreas: [String: CleaningArea] = [:]
        for (areaName, _) in Self.seedData {
            let area = CleaningArea(
                restaurantId: restaurantId,
                name: areaName,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(area)
            createdAreas[areaName] = area
        }

        for (areaName, tasks) in Self.seedData {
            guard let area = createdAreas[areaName] else { continue }
            for task in tasks {
                let task = CleaningTask(
                    restaurantId: restaurantId,
                    areaId: area.id,
                    areaNameSnapshot: area.name,
                    title: task.title,
                    frequency: task.frequency,
                    createdByUserId: user.id,
                    createdByNameSnapshot: user.name
                )
                modelContext.insert(task)
            }
        }
        try? modelContext.save()
    }

    func dueInterval(for task: CleaningTask, from reference: Date = Date(), calendar: Calendar) -> DateInterval {
        engine.periodInterval(
            for: task.frequency,
            customIntervalDays: task.customIntervalDays,
            reference: reference
        )
    }

    /// Chiude i record di cicli passati ancora «da fare» come «Non fatta».
    func closeStaleCleaningRecords(
        restaurantId: UUID,
        tasks: [CleaningTask],
        records: [CleaningRecord],
        calendar: Calendar,
        modelContext: ModelContext,
        now: Date = Date()
    ) {
        let scopedTasks = tasks.filter { $0.restaurantId == restaurantId && $0.isActive }
        let scopedRecords = records.filter { $0.restaurantId == restaurantId && !$0.isArchived }

        for task in scopedTasks {
            let currentPeriod = dueInterval(for: task, from: now, calendar: calendar)
            for record in scopedRecords where record.taskId == task.id && record.outcome == .daFare {
                guard record.periodStart != currentPeriod.start else { continue }
                record.outcome = .nonFatto
                record.updatedAt = now
                record.notes = record.notes ?? "Ciclo non completato"
            }
        }
    }

    /// Seed aree/task demo — una sola save, con yield tra le fasi.
    func ensureInitialTemplatesAsync(
        restaurantId: UUID,
        user: LocalUser,
        existingAreas: [CleaningArea],
        modelContext: ModelContext
    ) async {
        let scopedExisting = existingAreas.filter { $0.restaurantId == restaurantId }
        guard scopedExisting.isEmpty else { return }

        var createdAreas: [String: CleaningArea] = [:]
        for (areaName, _) in Self.seedData {
            let area = CleaningArea(
                restaurantId: restaurantId,
                name: areaName,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
            modelContext.insert(area)
            createdAreas[areaName] = area
        }
        await Task.yield()

        for (areaName, tasks) in Self.seedData {
            guard let area = createdAreas[areaName] else { continue }
            for task in tasks {
                let task = CleaningTask(
                    restaurantId: restaurantId,
                    areaId: area.id,
                    areaNameSnapshot: area.name,
                    title: task.title,
                    frequency: task.frequency,
                    createdByUserId: user.id,
                    createdByNameSnapshot: user.name
                )
                modelContext.insert(task)
            }
        }
        modelContext.saveSafely(operation: "cleaning-seed")
    }

    /// Ricrea i task seed se le aree esistono ma i task sono assenti (es. dopo dedupe o migrazione).
    func backfillSeedTasksIfNeeded(
        restaurantId: UUID,
        areas: [CleaningArea],
        existingTasks: [CleaningTask],
        user: LocalUser,
        modelContext: ModelContext
    ) async {
        let scopedTasks = existingTasks.filter { $0.restaurantId == restaurantId && $0.isActive }
        guard scopedTasks.isEmpty else { return }

        let areaByName = Dictionary(
            uniqueKeysWithValues: CleaningAreaGrouping.uniqueByName(areas)
                .map { (CleaningAreaGrouping.normalizeName($0.name), $0) }
        )
        guard !areaByName.isEmpty else { return }

        for (areaName, seedTasks) in Self.seedData {
            guard let area = areaByName[CleaningAreaGrouping.normalizeName(areaName)] else { continue }
            for seed in seedTasks {
                let task = CleaningTask(
                    restaurantId: restaurantId,
                    areaId: area.id,
                    areaNameSnapshot: area.name,
                    title: seed.title,
                    frequency: seed.frequency,
                    createdByUserId: user.id,
                    createdByNameSnapshot: user.name
                )
                modelContext.insert(task)
            }
        }
        await Task.yield()
        modelContext.saveSafely(operation: "cleaning-backfill-tasks")
    }

    func buildTaskCards(
        restaurantId: UUID,
        tasks: [CleaningTask],
        records: [CleaningRecord],
        criticalities: [CleaningCriticality],
        calendar: Calendar
    ) -> (todo: [CleaningTaskCard], overdue: [CleaningTaskCard], completed: [CleaningTaskCard], history: [CleaningRecord]) {
        let taskEngine = PeriodicTaskEngine(calendar: calendar)
        let activeTasks = tasks
            .filter { $0.restaurantId == restaurantId && $0.isActive }
            .sorted {
                if $0.areaNameSnapshot == $1.areaNameSnapshot { return $0.title < $1.title }
                return $0.areaNameSnapshot < $1.areaNameSnapshot
            }

        var todo: [CleaningTaskCard] = []
        var overdue: [CleaningTaskCard] = []
        var completed: [CleaningTaskCard] = []
        let now = Date()

        for task in activeTasks {
            let due = dueInterval(for: task, from: now, calendar: calendar)
            guard let record = records.first(where: { $0.taskId == task.id && $0.periodStart == due.start }) else { continue }
            let hasOpenCriticality = resolveCriticalityForRecord(record, criticalities: criticalities) != nil
            let adapter = CleaningRecordPeriodicAdapter(
                record: record,
                currentPeriodStart: due.start,
                hasOpenCriticality: hasOpenCriticality,
                now: now,
                engine: taskEngine
            )

            guard taskEngine.isVisibleOnDashboard(adapter, now: now) || adapter.lifecycleStatus.isTerminal else { continue }

            let isOverdue = taskEngine.isOverdueForDashboard(adapter, now: now)
            let isCompleted = adapter.lifecycleStatus == .completed || adapter.lifecycleStatus == .notApplicable
            let visibleDueDate = calendar.date(byAdding: .second, value: -1, to: due.end) ?? due.end
            let card = CleaningTaskCard(
                id: task.id,
                areaName: task.areaNameSnapshot,
                taskName: task.title,
                frequency: task.frequency,
                customIntervalDays: task.customIntervalDays,
                dueDate: visibleDueDate,
                isOverdue: isOverdue,
                isCompleted: isCompleted,
                record: record
            )
            if isCompleted {
                completed.append(card)
            } else if isOverdue {
                overdue.append(card)
            } else if adapter.lifecycleStatus == .pending || adapter.lifecycleStatus == .failed {
                todo.append(card)
            }
        }

        let history = records
            .filter {
                $0.restaurantId == restaurantId &&
                ($0.outcome == .pulito || $0.outcome == .nonPulito || $0.outcome == .nonApplicabile || $0.outcome == .nonFatto)
            }
            .sorted { $0.updatedAt > $1.updatedAt }

        return (todo, overdue, completed, history)
    }

    func ensureRecordForCurrentPeriod(
        task: CleaningTask,
        restaurantId: UUID,
        user: LocalUser,
        existingRecords: [CleaningRecord],
        calendar: Calendar,
        modelContext: ModelContext
    ) -> CleaningRecord {
        let due = dueInterval(for: task, calendar: calendar)
        if let existing = existingRecords.first(where: {
            $0.restaurantId == restaurantId &&
            $0.taskId == task.id &&
            $0.periodStart == due.start
        }) {
            return existing
        }

        let record = CleaningRecord(
            restaurantId: restaurantId,
            areaId: task.areaId,
            areaName: task.areaNameSnapshot,
            taskId: task.id,
            taskName: task.title,
            frequency: task.frequency,
            periodStart: due.start,
            periodEnd: due.end,
            outcome: .daFare,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            updatedByUserId: user.id,
            updatedByNameSnapshot: user.name
        )
        modelContext.insert(record)
        return record
    }

    func resolveCriticalityForRecord(
        _ record: CleaningRecord,
        criticalities: [CleaningCriticality]
    ) -> CleaningCriticality? {
        criticalities.first(where: { $0.recordId == record.id && $0.isResolved == false })
    }

    func summary(for cards: [CleaningTaskCard]) -> CleaningSummary {
        let total = cards.count
        let completed = cards.filter(\.isCompleted).count
        return CleaningSummary(completed: completed, total: total)
    }
}
