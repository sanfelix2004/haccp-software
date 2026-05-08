import Foundation
import SwiftData

struct OilControlService {
    private static let defaultPointNames = [
        "Friggitrice 1",
        "Friggitrice 2",
        "Friggitrice pesce",
        "Friggitrice carne",
        "Friggitrice verdure"
    ]

    private let validationService = OilValidationService()

    func ensureDefaultPoints(
        restaurantId: UUID,
        user: LocalUser,
        existingPoints: [OilPoint],
        modelContext: ModelContext
    ) {
        let scoped = existingPoints.filter { $0.restaurantId == restaurantId }
        for name in Self.defaultPointNames {
            let exists = scoped.contains { normalized($0.name) == normalized(name) }
            guard !exists else { continue }
            modelContext.insert(
                OilPoint(
                    restaurantId: restaurantId,
                    name: name,
                    createdByUserId: user.id,
                    createdByNameSnapshot: user.name
                )
            )
        }
        try? modelContext.save()
    }

    func addPoint(
        name: String,
        restaurantId: UUID,
        user: LocalUser,
        existingPoints: [OilPoint],
        modelContext: ModelContext
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard existingPoints.contains(where: { $0.restaurantId == restaurantId && normalized($0.name) == normalized(trimmed) }) == false else {
            throw NSError(domain: "OilControlService", code: 8001, userInfo: [NSLocalizedDescriptionKey: "Punto olio già presente."])
        }
        modelContext.insert(
            OilPoint(
                restaurantId: restaurantId,
                name: trimmed,
                createdByUserId: user.id,
                createdByNameSnapshot: user.name
            )
        )
        try modelContext.save()
    }

    func updatePoint(
        _ point: OilPoint,
        name: String,
        existingPoints: [OilPoint],
        modelContext: ModelContext
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard existingPoints.contains(where: {
            $0.id != point.id &&
            $0.restaurantId == point.restaurantId &&
            normalized($0.name) == normalized(trimmed)
        }) == false else {
            throw NSError(domain: "OilControlService", code: 8002, userInfo: [NSLocalizedDescriptionKey: "Esiste già un punto olio con questo nome."])
        }
        point.name = trimmed
        try modelContext.save()
    }

    func deletePoint(
        _ point: OilPoint,
        records: [OilControlRecord],
        modelContext: ModelContext
    ) throws {
        if records.contains(where: { $0.oilPointId == point.id }) {
            point.isActive = false
        } else {
            modelContext.delete(point)
        }
        try modelContext.save()
    }

    func saveCheck(
        point: OilPoint,
        checkedAt: Date,
        selectedStatus: OilStatus,
        polarCompoundsValue: Double?,
        temperature: Double?,
        actionTaken: OilAction,
        notes: String?,
        photoData: Data?,
        user: LocalUser,
        restaurantId: UUID,
        settings: HACCPSettings,
        modelContext: ModelContext
    ) throws -> OilControlRecord {
        let validation = validationService.validate(
            polarCompoundsValue: polarCompoundsValue,
            selectedStatus: selectedStatus,
            settings: settings
        )
        let cleanNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if validation.status.isCritical {
            guard cleanNotes?.isEmpty == false else {
                throw NSError(domain: "OilControlService", code: 8003, userInfo: [NSLocalizedDescriptionKey: "Per olio non conforme serve una nota."])
            }
            guard actionTaken != .nessunaAzione else {
                throw NSError(domain: "OilControlService", code: 8004, userInfo: [NSLocalizedDescriptionKey: "Per olio non conforme serve un'azione correttiva."])
            }
            if settings.oilNonCompliancePhotoRequired {
                guard let photoData, photoData.isEmpty == false else {
                    throw NSError(domain: "OilControlService", code: 8005, userInfo: [NSLocalizedDescriptionKey: "Per una non conformità olio è obbligatoria una foto."])
                }
            }
        }

        let record = OilControlRecord(
            restaurantId: restaurantId,
            oilPointId: point.id,
            oilPointNameSnapshot: point.name,
            checkedAt: checkedAt,
            oilStatus: validation.status,
            polarCompoundsValue: polarCompoundsValue,
            temperature: temperature,
            actionTaken: actionTaken,
            notes: cleanNotes?.isEmpty == false ? cleanNotes : nil,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            nonCompliancePhotoData: photoData
        )
        modelContext.insert(record)

        if validation.status.isCritical {
            let valueText = polarCompoundsValue.map { String(format: "%.1f%%", $0) } ?? "valore non indicato"
            modelContext.insert(
                OilControlAlert(
                    restaurantId: restaurantId,
                    recordId: record.id,
                    oilPointName: point.name,
                    message: "\(validation.status.label): \(valueText). Azione: \(actionTaken.label)"
                )
            )
        }

        try modelContext.save()
        return record
    }

    func deleteRecord(
        _ record: OilControlRecord,
        alerts: [OilControlAlert],
        modelContext: ModelContext
    ) throws {
        for alert in alerts where alert.recordId == record.id {
            modelContext.delete(alert)
        }
        modelContext.delete(record)
        try modelContext.save()
    }

    func resolveAlert(
        _ alert: OilControlAlert,
        user: LocalUser,
        modelContext: ModelContext
    ) throws {
        alert.isActive = false
        alert.resolvedAt = Date()
        alert.resolvedByUserId = user.id
        alert.resolvedByNameSnapshot = user.name
        try modelContext.save()
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
