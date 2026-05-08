import Foundation
import SwiftData

@Model
final class OilControlRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var oilPointId: UUID = UUID()
    var oilPointNameSnapshot: String = ""
    var checkedAt: Date
    var oilState: String = OilStatus.conforme.rawValue
    var oilStatusRaw: String = OilStatus.conforme.rawValue
    var indexValue: Double?
    var polarCompoundsValue: Double?
    var temperature: Double?
    var actionTaken: String = OilAction.nessunaAzione.rawValue
    var notes: String?
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var nonCompliancePhotoData: Data?

    var oilStatus: OilStatus {
        get {
            OilStatus(rawValue: oilStatusRaw)
                ?? OilStatus(rawValue: oilState)
                ?? OilStatus.fromLegacy(oilState)
                ?? .conforme
        }
        set {
            oilStatusRaw = newValue.rawValue
            oilState = newValue.rawValue
        }
    }

    var oilAction: OilAction {
        get {
            OilAction(rawValue: actionTaken)
                ?? OilAction.fromLegacy(actionTaken)
                ?? .nessunaAzione
        }
        set { actionTaken = newValue.rawValue }
    }

    var effectivePolarCompoundsValue: Double? {
        polarCompoundsValue ?? indexValue
    }

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        oilPointId: UUID,
        oilPointNameSnapshot: String,
        checkedAt: Date,
        oilStatus: OilStatus,
        polarCompoundsValue: Double? = nil,
        temperature: Double? = nil,
        actionTaken: OilAction,
        notes: String? = nil,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        nonCompliancePhotoData: Data? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.oilPointId = oilPointId
        self.oilPointNameSnapshot = oilPointNameSnapshot
        self.checkedAt = checkedAt
        self.oilState = oilStatus.rawValue
        self.oilStatusRaw = oilStatus.rawValue
        self.indexValue = polarCompoundsValue
        self.polarCompoundsValue = polarCompoundsValue
        self.temperature = temperature
        self.actionTaken = actionTaken.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.nonCompliancePhotoData = nonCompliancePhotoData
    }
}

@Model
final class OilControlAlert {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var recordId: UUID
    var oilPointName: String
    var message: String
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedByUserId: UUID?
    var resolvedByNameSnapshot: String?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        recordId: UUID,
        oilPointName: String,
        message: String,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil,
        resolvedByUserId: UUID? = nil,
        resolvedByNameSnapshot: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.recordId = recordId
        self.oilPointName = oilPointName
        self.message = message
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.resolvedByUserId = resolvedByUserId
        self.resolvedByNameSnapshot = resolvedByNameSnapshot
        self.isActive = isActive
    }
}
