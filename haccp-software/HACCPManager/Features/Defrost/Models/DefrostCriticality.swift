//
//  DefrostCriticality.swift
//

import Foundation
import SwiftData

@Model
final class DefrostCriticality {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var recordId: UUID
    var productName: String
    var reason: String
    var correctiveAction: String
    var isResolved: Bool
    var createdAt: Date
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var resolvedAt: Date?
    var resolvedByUserId: UUID?
    var resolvedByNameSnapshot: String?
    var photoData: Data?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        recordId: UUID,
        productName: String,
        reason: String,
        correctiveAction: String,
        isResolved: Bool = false,
        createdAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        resolvedAt: Date? = nil,
        resolvedByUserId: UUID? = nil,
        resolvedByNameSnapshot: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.recordId = recordId
        self.productName = productName
        self.reason = reason
        self.correctiveAction = correctiveAction
        self.isResolved = isResolved
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.resolvedAt = resolvedAt
        self.resolvedByUserId = resolvedByUserId
        self.resolvedByNameSnapshot = resolvedByNameSnapshot
        self.photoData = photoData
    }
}
