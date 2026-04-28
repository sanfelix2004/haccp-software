import Foundation
import SwiftData

@MainActor
final class TemperatureModuleService {
    private let validationService = TemperatureValidationService()

    func addRecord(
        value: Double,
        measuredAt: Date,
        notes: String?,
        correctiveAction: String?,
        device: TemperatureDevice,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws -> TemperatureRecord {
        let settings = SettingsStorageService.shared.haccp
        let validation = validationService.validate(value: value, device: device, settings: settings)

        let finalCorrectiveAction: String?
        if validation.status == .outOfRange || validation.status == .critical {
            finalCorrectiveAction = (correctiveAction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? correctiveAction
                : "Azione correttiva non indicata"
        } else {
            finalCorrectiveAction = correctiveAction
        }

        let record = TemperatureRecord(
            restaurantId: restaurantId,
            deviceId: device.id,
            deviceName: device.name,
            value: value,
            measuredAt: measuredAt,
            measuredByUserId: user.id,
            measuredByName: user.name,
            minAllowed: validation.minAllowed,
            maxAllowed: validation.maxAllowed,
            status: validation.status,
            notes: notes,
            correctiveAction: finalCorrectiveAction
        )
        modelContext.insert(record)

        if validation.status == .outOfRange || validation.status == .critical {
            let alert = TemperatureAlert(
                restaurantId: restaurantId,
                recordId: record.id,
                deviceName: device.name,
                severity: validation.severity,
                message: validation.message
            )
            modelContext.insert(alert)
        }

        log(
            action: "TEMPERATURE_RECORD_CREATED",
            user: user,
            restaurantId: restaurantId,
            deviceName: device.name,
            details: "Valore: \(value)C, Stato: \(validation.status.rawValue)",
            modelContext: modelContext
        )

        try modelContext.save()
        return record
    }

    func resolveAlert(
        _ alert: TemperatureAlert,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws {
        alert.isActive = false
        alert.resolvedAt = Date()
        log(
            action: "TEMPERATURE_ALERT_RESOLVED",
            user: user,
            restaurantId: restaurantId,
            deviceName: alert.deviceName,
            details: alert.message,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func deleteDevice(
        _ device: TemperatureDevice,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws {
        let records = (try? modelContext.fetch(FetchDescriptor<TemperatureRecord>())) ?? []
        for record in records where record.deviceId == device.id {
            record.isArchived = true
        }

        device.isActive = false
        log(
            action: "TEMPERATURE_DEVICE_DISABLED",
            user: user,
            restaurantId: restaurantId,
            deviceName: device.name,
            details: "Dispositivo disattivato e record archiviati",
            modelContext: modelContext
        )
        try modelContext.save()
    }

    func log(
        action: String,
        user: LocalUser,
        restaurantId: UUID,
        deviceName: String,
        details: String?,
        modelContext: ModelContext
    ) {
        let audit = TemperatureAuditLog(
            restaurantId: restaurantId,
            userId: user.id,
            userName: user.name,
            action: action,
            deviceName: deviceName,
            details: details
        )
        modelContext.insert(audit)
    }
}
