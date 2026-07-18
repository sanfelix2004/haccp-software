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
            HACCPLocalNotificationService.notifyTemperatureAlert(
                deviceName: device.name,
                message: validation.message,
                recordId: record.id
            )
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
        KitchenProcessNotifications.postRecordsDidChange()
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
        KitchenProcessNotifications.postRecordsDidChange()
    }

    func deleteDevice(
        _ device: TemperatureDevice,
        user: LocalUser,
        restaurantId: UUID,
        modelContext: ModelContext
    ) throws {
        let records = (try? modelContext.fetch(FetchDescriptor<TemperatureRecord>())) ?? []
        let deviceRecordIds = Set(records.filter { $0.deviceId == device.id }.map(\.id))
        for record in records where record.deviceId == device.id {
            record.isArchived = true
        }
        let alerts = (try? modelContext.fetch(FetchDescriptor<TemperatureAlert>())) ?? []
        for alert in alerts where alert.restaurantId == restaurantId &&
            alert.isActive &&
            (deviceRecordIds.contains(alert.recordId) || alert.deviceName == device.name) {
            alert.isActive = false
            alert.resolvedAt = Date()
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
