import Foundation
import SwiftData

/// Migrazione una tantum: attività di Programmazione → modelli checklist «Attività rapida».
@MainActor
enum SchedulingToChecklistMigrationService {
    private static let migrationKey = "scheduling_to_checklist_migrated_v1"

    static func migrateIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let tasks = (try? modelContext.fetch(FetchDescriptor<ScheduledTask>())) ?? []
        guard !tasks.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let users = (try? modelContext.fetch(FetchDescriptor<LocalUser>())) ?? []
        let checklistService = ChecklistService()
        var migrated = 0

        for task in tasks {
            guard let user = users.first(where: { $0.id == task.createdByUserId })
                ?? users.first(where: { $0.role == .master })
                ?? users.first else {
                continue
            }

            let calendar = Calendar.current
            let hour = task.dueAt.map { calendar.component(.hour, from: $0) }
            let minute = task.dueAt.map { calendar.component(.minute, from: $0) }

            do {
                _ = try checklistService.createQuickTaskTemplate(
                    restaurantId: task.restaurantId,
                    title: task.title,
                    description: task.taskDescription,
                    frequency: mapFrequency(task.frequency),
                    scheduledHour: hour,
                    scheduledMinute: minute,
                    createdBy: user,
                    modelContext: modelContext
                )
                modelContext.delete(task)
                migrated += 1
            } catch {
                continue
            }
        }

        if migrated > 0 {
            try? modelContext.save()
        }
        if migrated == tasks.count || tasks.isEmpty {
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }

    private static func mapFrequency(_ frequency: SchedulingFrequency) -> ChecklistFrequency {
        switch frequency {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .custom: return .onDemand
        }
    }
}
