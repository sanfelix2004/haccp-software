import Foundation
import SwiftData

enum CleaningAreaGrouping {

    static func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Una sola area per nome (case-insensitive); mantiene la più vecchia.
    static func uniqueByName(_ areas: [CleaningArea]) -> [CleaningArea] {
        var canonicalByKey: [String: CleaningArea] = [:]
        for area in areas {
            let key = normalizeName(area.name)
            guard !key.isEmpty else { continue }
            if let existing = canonicalByKey[key] {
                if area.createdAt < existing.createdAt {
                    canonicalByKey[key] = area
                }
            } else {
                canonicalByKey[key] = area
            }
        }
        return canonicalByKey.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Unisce aree duplicate nel database e riallinea i task collegati.
    @discardableResult
    static func deduplicateInStore(
        restaurantId: UUID,
        areas: [CleaningArea],
        tasks: [CleaningTask],
        modelContext: ModelContext
    ) -> Int {
        let scopedAreas = areas.filter { $0.restaurantId == restaurantId }
        var canonicalByKey: [String: CleaningArea] = [:]
        var duplicates: [CleaningArea] = []

        for area in scopedAreas.sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = normalizeName(area.name)
            guard !key.isEmpty else { continue }
            if let canonical = canonicalByKey[key] {
                duplicates.append(area)
                for task in tasks where task.restaurantId == restaurantId && task.areaId == area.id {
                    task.areaId = canonical.id
                    task.areaNameSnapshot = canonical.name
                }
            } else {
                canonicalByKey[key] = area
            }
        }

        guard !duplicates.isEmpty else { return 0 }
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
        modelContext.saveSafely(operation: "cleaning-dedupe-areas")
        return duplicates.count
    }

    /// Rimuove task pulizia duplicati (stessa area + titolo + frequenza).
    @discardableResult
    static func deduplicateTasksInStore(
        restaurantId: UUID,
        tasks: [CleaningTask],
        modelContext: ModelContext
    ) -> Int {
        var canonicalByKey: [String: CleaningTask] = [:]
        var duplicates: [CleaningTask] = []

        for task in tasks
            .filter({ $0.restaurantId == restaurantId && $0.isActive })
            .sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = taskDedupeKey(task)
            if canonicalByKey[key] != nil {
                duplicates.append(task)
            } else {
                canonicalByKey[key] = task
            }
        }

        guard !duplicates.isEmpty else { return 0 }
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
        modelContext.saveSafely(operation: "cleaning-dedupe-tasks")
        return duplicates.count
    }

    private static func taskDedupeKey(_ task: CleaningTask) -> String {
        let area = normalizeName(task.areaNameSnapshot)
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(area)|\(title)|\(task.frequencyRaw)"
    }
}
