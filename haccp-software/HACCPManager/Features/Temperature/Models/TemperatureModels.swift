import Foundation
import SwiftData
import Combine

enum TemperatureDeviceType: String, Codable, CaseIterable {
    case fridge = "FRIDGE"
    case freezer = "FREEZER"
    case blastChiller = "BLAST_CHILLER"
    case hotHolding = "HOT_HOLDING"
    case ambient = "AMBIENT"

    var label: String { rawValue.replacingOccurrences(of: "_", with: " ") }
}

enum TemperatureUnit: String, Codable {
    case celsius = "C"
}

enum TemperatureStatus: String, Codable, CaseIterable {
    case ok = "OK"
    case warning = "WARNING"
    case outOfRange = "OUT_OF_RANGE"
    case critical = "CRITICAL"

    var order: Int {
        switch self {
        case .ok: return 0
        case .warning: return 1
        case .outOfRange: return 2
        case .critical: return 3
        }
    }
}

enum TemperatureSeverity: String, Codable {
    case info = "INFO"
    case warning = "WARNING"
    case high = "HIGH"
    case critical = "CRITICAL"
}

@Model
final class TemperatureDevice {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var name: String
    var typeRaw: String
    var customMinTemp: Double?
    var customMaxTemp: Double?
    var isActive: Bool
    var createdAt: Date

    var type: TemperatureDeviceType {
        get { TemperatureDeviceType(rawValue: typeRaw) ?? .fridge }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        name: String,
        type: TemperatureDeviceType,
        customMinTemp: Double? = nil,
        customMaxTemp: Double? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.typeRaw = type.rawValue
        self.customMinTemp = customMinTemp
        self.customMaxTemp = customMaxTemp
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

@Model
final class TemperatureRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var deviceId: UUID
    var deviceName: String
    var value: Double
    var unitRaw: String
    var measuredAt: Date
    var measuredByUserId: UUID
    var measuredByName: String
    var minAllowed: Double
    var maxAllowed: Double
    var statusRaw: String
    var notes: String?
    var correctiveAction: String?
    var isArchived: Bool
    var createdAt: Date

    var unit: TemperatureUnit {
        get { TemperatureUnit(rawValue: unitRaw) ?? .celsius }
        set { unitRaw = newValue.rawValue }
    }

    var status: TemperatureStatus {
        get { TemperatureStatus(rawValue: statusRaw) ?? .ok }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        deviceId: UUID,
        deviceName: String,
        value: Double,
        unit: TemperatureUnit = .celsius,
        measuredAt: Date,
        measuredByUserId: UUID,
        measuredByName: String,
        minAllowed: Double,
        maxAllowed: Double,
        status: TemperatureStatus,
        notes: String? = nil,
        correctiveAction: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.value = value
        self.unitRaw = unit.rawValue
        self.measuredAt = measuredAt
        self.measuredByUserId = measuredByUserId
        self.measuredByName = measuredByName
        self.minAllowed = minAllowed
        self.maxAllowed = maxAllowed
        self.statusRaw = status.rawValue
        self.notes = notes
        self.correctiveAction = correctiveAction
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

@Model
final class TemperatureAlert {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var recordId: UUID
    var deviceName: String
    var severityRaw: String
    var message: String
    var createdAt: Date
    var resolvedAt: Date?
    var isActive: Bool

    var severity: TemperatureSeverity {
        get { TemperatureSeverity(rawValue: severityRaw) ?? .warning }
        set { severityRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        recordId: UUID,
        deviceName: String,
        severity: TemperatureSeverity,
        message: String,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.recordId = recordId
        self.deviceName = deviceName
        self.severityRaw = severity.rawValue
        self.message = message
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.isActive = isActive
    }
}

@Model
final class TemperatureAuditLog {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var userId: UUID
    var userName: String
    var action: String
    var deviceName: String
    var details: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        userId: UUID,
        userName: String,
        action: String,
        deviceName: String,
        details: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.userId = userId
        self.userName = userName
        self.action = action
        self.deviceName = deviceName
        self.details = details
        self.createdAt = createdAt
    }
}
