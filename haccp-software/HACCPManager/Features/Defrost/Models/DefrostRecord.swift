import Foundation
import SwiftData

@Model
final class DefrostRecord {
    @Attribute(.unique) var id: UUID
    var restaurantId: UUID
    var productName: String
    /// Snapshot etichetta metodo (compatibilità storico).
    var method: String
    var methodRaw: String = DefrostMethod.frigorifero.rawValue
    var lotNumber: String?
    var traceabilityItemId: UUID?
    var startAt: Date
    var expectedEndAt: Date?
    var endAt: Date?
    var finalTemperature: Double?
    var statusRaw: String = DefrostStatus.inProgress.rawValue
    var outcomeRaw: String?
    var createdAt: Date
    var updatedAt: Date = Date()
    var createdByUserId: UUID
    var createdByNameSnapshot: String
    var notes: String?
    var correctiveAction: String?
    var operatorSignature: String?
    var isArchived: Bool = false
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        restaurantId: UUID,
        productName: String,
        method: DefrostMethod,
        lotNumber: String? = nil,
        traceabilityItemId: UUID? = nil,
        startAt: Date = Date(),
        expectedEndAt: Date? = nil,
        endAt: Date? = nil,
        finalTemperature: Double? = nil,
        status: DefrostStatus = .inProgress,
        outcome: DefrostOutcome? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdByUserId: UUID,
        createdByNameSnapshot: String,
        notes: String? = nil,
        correctiveAction: String? = nil,
        operatorSignature: String? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.productName = productName
        self.methodRaw = method.rawValue
        self.method = method.label
        self.lotNumber = lotNumber
        self.traceabilityItemId = traceabilityItemId
        self.startAt = startAt
        self.expectedEndAt = expectedEndAt
        self.endAt = endAt
        self.finalTemperature = finalTemperature
        self.statusRaw = status.rawValue
        self.outcomeRaw = outcome?.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByUserId = createdByUserId
        self.createdByNameSnapshot = createdByNameSnapshot
        self.notes = notes
        self.correctiveAction = correctiveAction
        self.operatorSignature = operatorSignature
    }
}

extension DefrostRecord {
    var defrostMethod: DefrostMethod {
        get { DefrostMethod.fromStored(methodRaw.isEmpty ? method : methodRaw) }
        set {
            methodRaw = newValue.rawValue
            method = newValue.label
        }
    }

    var defrostStatus: DefrostStatus {
        get {
            if let stored = DefrostStatus(rawValue: statusRaw),
               stored != .inProgress, stored != .delayed {
                return stored
            }
            return computedStatus(at: Date())
        }
        set { statusRaw = newValue.rawValue }
    }

    var outcome: DefrostOutcome? {
        get { outcomeRaw.flatMap { DefrostOutcome(rawValue: $0) } }
        set { outcomeRaw = newValue?.rawValue }
    }

    /// Processo ancora aperto in cucina (overlay + sezione "In corso").
    var isActive: Bool {
        endAt == nil && DefrostStatus.isOpen(rawValue: statusRaw)
    }

    var duration: TimeInterval? {
        guard let end = endAt else { return nil }
        return end.timeIntervalSince(startAt)
    }

    var durationText: String {
        guard let duration else { return "—" }
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) min"
    }

    /// Stato calcolato per record non chiusi.
    /// Stato da mostrare in UI (calcolato se ancora aperto).
    func displayStatus(at date: Date = Date()) -> DefrostStatus {
        if endAt != nil, let stored = DefrostStatus(rawValue: statusRaw) {
            return stored
        }
        return computedStatus(at: date)
    }

    func computedStatus(at date: Date = Date()) -> DefrostStatus {
        if statusRaw == DefrostStatus.cancelled.rawValue {
            return .cancelled
        }
        if let endAt {
            if outcome == .nonConforme || statusRaw == DefrostStatus.completedWithCriticality.rawValue {
                return .completedWithCriticality
            }
            return .completed
        }
        if let expected = expectedEndAt, date > expected {
            return .delayed
        }
        return .inProgress
    }

    func refreshComputedStatus(at date: Date = Date()) {
        guard endAt == nil else { return }
        statusRaw = computedStatus(at: date).rawValue
    }

    /// Data per ordinamento e filtri storico (preferisce chiusura).
    var historyAnchorDate: Date {
        endAt ?? startAt
    }

    /// Etichetta stato per storico (sempre coerente dopo chiusura).
    var historyStatusLabel: String {
        if endAt != nil, let stored = DefrostStatus(rawValue: statusRaw) {
            return stored.label
        }
        return displayStatus().label
    }
}

struct DefrostNewDraft: Equatable {
    var productName: String = ""
    var lotNumber: String = ""
    var traceabilityItemId: UUID?
    var method: DefrostMethod = .frigorifero
    var startAt: Date = Date()
    var notes: String = ""

    var isValid: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct DefrostCompleteDraft: Equatable {
    var actualEndAt: Date = Date()
    var finalTemperature: String = ""
    var outcome: DefrostOutcome = .conforme
    var notes: String = ""
    var correctiveAction: String = ""
    var criticalityReason: String = ""
}

struct DefrostFilter: Equatable {
    var searchText: String = ""
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var status: String = "Tutti"
    var method: String = "Tutti"
}
