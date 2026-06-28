import Foundation
import SwiftData

/// Non conformità bloccante registrata durante la ricezione merci.
@Model
final class NonConformitaRicezione {
    @Attribute(.unique) var id: UUID
    var ricezioneMerceId: UUID
    var restaurantId: UUID
    var descrizione: String
    var azioneRaw: String
    /// JSON-encoded `[UUID]` → `ProductImage.id`
    var photoIdsData: Data?
    var createdAt: Date
    var createdByUserId: UUID?
    var createdByNameSnapshot: String
    var resolvedAt: Date?
    var resolvedByNameSnapshot: String?

    init(
        id: UUID = UUID(),
        ricezioneMerceId: UUID,
        restaurantId: UUID,
        descrizione: String,
        azione: AzioneNonConformita,
        photoIds: [UUID] = [],
        createdAt: Date = Date(),
        createdByUserId: UUID?,
        createdByNameSnapshot: String,
        resolvedAt: Date? = nil,
        resolvedByNameSnapshot: String? = nil
    ) {
        self.id = id
        self.ricezioneMerceId = ricezioneMerceId
        self.restaurantId = restaurantId
        self.descrizione = descrizione
        self.azioneRaw = azione.rawValue
        self.photoIdsData = try? JSONEncoder().encode(photoIds)
        self.createdAt = createdAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.resolvedAt = resolvedAt
        self.resolvedByNameSnapshot = resolvedByNameSnapshot
    }

    var azione: AzioneNonConformita {
        get { AzioneNonConformita(rawValue: azioneRaw) ?? .scartata }
        set { azioneRaw = newValue.rawValue }
    }

    var photoIds: [UUID] {
        get {
            guard let photoIdsData else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: photoIdsData)) ?? []
        }
        set { photoIdsData = try? JSONEncoder().encode(newValue) }
    }
}
