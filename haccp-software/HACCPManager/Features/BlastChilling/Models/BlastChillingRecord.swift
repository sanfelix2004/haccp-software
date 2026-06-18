import Foundation
import SwiftData

@Model
final class BlastChillingRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productionId: UUID?
    var traceabilityItemId: UUID?
    var lotNumberSnapshot: String?
    var productionNameSnapshot: String
    var productionCategorySnapshot: String
    var startedAt: Date
    var endedAt: Date?
    var initialTemperature: Double
    var finalTemperature: Double?
    var targetTemperature: Double
    var statusRaw: String
    var notes: String?
    var correctiveAction: String?
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var createdAt: Date
    var updatedAt: Date
    var operatorSignature: String?
    var isArchived: Bool = false
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productionId: UUID? = nil,
        traceabilityItemId: UUID? = nil,
        lotNumberSnapshot: String? = nil,
        productionNameSnapshot: String,
        productionCategorySnapshot: String,
        startedAt: Date,
        endedAt: Date? = nil,
        initialTemperature: Double,
        finalTemperature: Double? = nil,
        targetTemperature: Double = -18,
        status: BlastChillingStatus = .inCorso,
        notes: String? = nil,
        correctiveAction: String? = nil,
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productionId = productionId
        self.traceabilityItemId = traceabilityItemId
        self.lotNumberSnapshot = lotNumberSnapshot
        self.productionNameSnapshot = productionNameSnapshot
        self.productionCategorySnapshot = productionCategorySnapshot
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.initialTemperature = initialTemperature
        self.finalTemperature = finalTemperature
        self.targetTemperature = targetTemperature
        self.statusRaw = status.rawValue
        self.notes = notes
        self.correctiveAction = correctiveAction
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.operatorSignature = operatorSignature
    }

    var status: BlastChillingStatus {
        get { BlastChillingStatus(rawValue: statusRaw) ?? .inCorso }
        set { statusRaw = newValue.rawValue }
    }

    var productName: String {
        get { productionNameSnapshot }
        set { productionNameSnapshot = newValue }
    }

    var outcome: String {
        get { status.label }
        set { statusRaw = BlastChillingStatus.allCases.first(where: { $0.label == newValue || $0.rawValue == newValue })?.rawValue ?? newValue }
    }
}

extension BlastChillingRecord {
    var isActive: Bool {
        status == .inCorso && endedAt == nil
    }

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return max(0, end.timeIntervalSince(startedAt))
    }

    var durationText: String {
        guard let duration else { return "—" }
        return ProcessElapsedFormatter.formatReadable(elapsed: duration)
    }
}
