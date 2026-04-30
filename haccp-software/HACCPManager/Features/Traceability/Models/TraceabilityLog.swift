import Foundation
import SwiftData

enum TraceabilityActionType: String, Codable {
    case created = "CREATED"
    case linkedToProduction = "LINKED_TO_PRODUCTION"
    case expired = "EXPIRED"
    case rejected = "REJECTED"
}

@Model
final class TraceabilityLog {
    @Attribute(.unique) var id: UUID
    var receivedItemId: UUID
    var productionId: UUID?
    var actionTypeRaw: String
    var timestamp: Date
    var operatorName: String

    init(
        id: UUID = UUID(),
        receivedItemId: UUID,
        productionId: UUID? = nil,
        actionType: TraceabilityActionType,
        timestamp: Date = Date(),
        operatorName: String
    ) {
        self.id = id
        self.receivedItemId = receivedItemId
        self.productionId = productionId
        self.actionTypeRaw = actionType.rawValue
        self.timestamp = timestamp
        self.operatorName = operatorName
    }

    var actionType: TraceabilityActionType {
        get { TraceabilityActionType(rawValue: actionTypeRaw) ?? .created }
        set { actionTypeRaw = newValue.rawValue }
    }
}
