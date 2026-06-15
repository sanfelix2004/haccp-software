import Foundation
import SwiftData

struct SchedulingService {
    func dueCount(tasks: [ScheduledTask], now: Date = Date()) -> Int {
        tasks.filter { !$0.isCompleted && ($0.dueAt ?? .distantFuture) <= now }.count
    }

    /// Attività non completate la cui scadenza è già passata.
    func isOverdue(_ task: ScheduledTask, now: Date = Date()) -> Bool {
        guard !task.isCompleted, let due = task.dueAt else { return false }
        return due < now
    }

    @discardableResult
    func createTask(
        restaurantId: UUID,
        title: String,
        description: String,
        frequency: SchedulingFrequency,
        dueAt: Date?,
        user: LocalUser,
        modelContext: ModelContext
    ) throws -> ScheduledTask {
        let task = ScheduledTask(
            restaurantId: restaurantId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            taskDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            dueAt: dueAt,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(task)
        try modelContext.save()
        return task
    }

    func setCompleted(_ task: ScheduledTask, completed: Bool, user: LocalUser?, modelContext: ModelContext) throws {
        task.isCompleted = completed
        task.operatorSignature = completed ? user?.name : nil
        try modelContext.save()
    }

    func delete(_ task: ScheduledTask, modelContext: ModelContext) throws {
        modelContext.delete(task)
        try modelContext.save()
    }
}
