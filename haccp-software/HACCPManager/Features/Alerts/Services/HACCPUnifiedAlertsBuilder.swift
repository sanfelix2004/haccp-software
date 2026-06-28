import Foundation

/// Voce normalizzata per Avvisi e badge dashboard.
struct HACCPAlertCandidate: Identifiable {
    let id: UUID
    let module: String
    let icon: String
    let title: String
    let detail: String?
    let date: Date
    let severity: HACCPBadgeStyle
    let navigationTarget: SidebarItem?
    let checklistAlert: ChecklistAlert?
    let resolve: (() -> Void)?

    var isResolvable: Bool { checklistAlert != nil || resolve != nil }
}

enum HACCPUnifiedAlertsBuilder {

    static func build(
        restaurantId: UUID,
        temperatureAlerts: [TemperatureAlert],
        cleaningCriticalities: [CleaningCriticality],
        defrostCriticalities: [DefrostCriticality],
        oilAlerts: [OilControlAlert],
        checklistAlerts: [ChecklistAlert],
        traceabilityRecords: [TraceabilityRecord],
        goodsReceipts: [GoodsReceivingRecord],
        productionLabels: [ProductionLabelRecord],
        soonThresholdDays: Int,
        resolveTemperature: @escaping (TemperatureAlert) -> Void,
        resolveCleaning: @escaping (CleaningCriticality) -> Void,
        resolveDefrost: @escaping (DefrostCriticality) -> Void,
        resolveOil: @escaping (OilControlAlert) -> Void,
        resolveTraceabilityNC: @escaping (TraceabilityRecord) -> Void,
        resolveGoodsNC: @escaping (GoodsReceivingRecord) -> Void
    ) -> [HACCPAlertCandidate] {
        var result: [HACCPAlertCandidate] = []

        result += temperatureAlerts
            .filter { $0.restaurantId == restaurantId && $0.isActive }
            .map { alert in
                HACCPAlertCandidate(
                    id: alert.id,
                    module: "Temperature",
                    icon: "thermometer.medium",
                    title: "Temperatura fuori range · \(alert.deviceName)",
                    detail: alert.message,
                    date: alert.createdAt,
                    severity: temperatureBadgeStyle(for: alert.severity),
                    navigationTarget: .fridges,
                    checklistAlert: nil,
                    resolve: { resolveTemperature(alert) }
                )
            }

        result += cleaningCriticalities
            .filter { $0.restaurantId == restaurantId && !$0.isResolved }
            .map { c in
                HACCPAlertCandidate(
                    id: c.id,
                    module: "Pulizia",
                    icon: "sparkles",
                    title: "Pulizia non conforme · \(c.areaName)",
                    detail: "\(c.taskName) — Azione: \(c.correctiveAction)",
                    date: c.createdAt,
                    severity: .nonConforme,
                    navigationTarget: .cleaningControl,
                    checklistAlert: nil,
                    resolve: { resolveCleaning(c) }
                )
            }

        result += defrostCriticalities
            .filter { $0.restaurantId == restaurantId && !$0.isResolved }
            .map { c in
                HACCPAlertCandidate(
                    id: c.id,
                    module: "Decongelamento",
                    icon: "snowflake",
                    title: "Decongelamento · \(c.productName)",
                    detail: "\(c.reason) — Azione: \(c.correctiveAction)",
                    date: c.createdAt,
                    severity: .warning,
                    navigationTarget: .defrost,
                    checklistAlert: nil,
                    resolve: { resolveDefrost(c) }
                )
            }

        result += oilAlerts
            .filter { $0.restaurantId == restaurantId && $0.isActive }
            .map { alert in
                HACCPAlertCandidate(
                    id: alert.id,
                    module: "Olio",
                    icon: "drop.fill",
                    title: "Olio critico · \(alert.oilPointName)",
                    detail: alert.message,
                    date: alert.createdAt,
                    severity: .warning,
                    navigationTarget: .oilControl,
                    checklistAlert: nil,
                    resolve: { resolveOil(alert) }
                )
            }

        result += checklistAlerts
            .filter { $0.restaurantId == restaurantId && $0.isActive }
            .map { alert in
                HACCPAlertCandidate(
                    id: alert.id,
                    module: "Checklist",
                    icon: "checklist",
                    title: alert.message,
                    detail: nil,
                    date: alert.createdAt,
                    severity: checklistBadgeStyle(for: alert.severity),
                    navigationTarget: .checklist,
                    checklistAlert: alert,
                    resolve: nil
                )
            }

        result += expiryAlerts(
            records: traceabilityRecords.filter { $0.restaurantId == restaurantId },
            soonThresholdDays: soonThresholdDays
        )

        result += traceabilityRecords
            .filter {
                $0.restaurantId == restaurantId
                    && $0.isNonCompliant
                    && $0.nonComplianceResolvedAt == nil
                    && $0.productStatus != .used
            }
            .map { record in
                HACCPAlertCandidate(
                    id: alertUUID(namespace: 0xA2, source: record.id),
                    module: "Tracciabilità",
                    icon: "exclamationmark.triangle.fill",
                    title: "Non conformità · \(record.productName)",
                    detail: record.nonComplianceNote ?? record.notes,
                    date: record.receivedAt,
                    severity: .nonConforme,
                    navigationTarget: .traceability,
                    checklistAlert: nil,
                    resolve: { resolveTraceabilityNC(record) }
                )
            }

        result += goodsReceipts
            .filter {
                $0.restaurantId == restaurantId
                    && $0.status != .conforme
                    && $0.nonComplianceResolvedAt == nil
            }
            .map { receipt in
                HACCPAlertCandidate(
                    id: alertUUID(namespace: 0xA3, source: receipt.id),
                    module: "Ricezione merci",
                    icon: "shippingbox.fill",
                    title: "NC ricezione · \(receipt.productNameSnapshot)",
                    detail: [receipt.notes, receipt.correctiveAction]
                        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " — "),
                    date: receipt.receivedAt,
                    severity: .nonConforme,
                    navigationTarget: .goodsReceiving,
                    checklistAlert: nil,
                    resolve: { resolveGoodsNC(receipt) }
                )
            }

        result += productionLabels
            .filter { $0.restaurantId == restaurantId && !$0.isArchived }
            .compactMap { label -> HACCPAlertCandidate? in
                switch label.expiryState {
                case .expired:
                    return HACCPAlertCandidate(
                        id: alertUUID(namespace: 0xA4, source: label.id),
                        module: "Etichette",
                        icon: "tag.fill",
                        title: "Etichetta scaduta · \(label.productName)",
                        detail: "Scadenza \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))",
                        date: label.expiryDate,
                        severity: .nonConforme,
                        navigationTarget: .productionLabels,
                        checklistAlert: nil,
                        resolve: nil
                    )
                case .soon:
                    return HACCPAlertCandidate(
                        id: alertUUID(namespace: 0xA5, source: label.id),
                        module: "Etichette",
                        icon: "tag.fill",
                        title: "Etichetta in scadenza · \(label.productName)",
                        detail: "Scadenza \(label.expiryDate.formatted(date: .abbreviated, time: .omitted))",
                        date: label.expiryDate,
                        severity: .warning,
                        navigationTarget: .productionLabels,
                        checklistAlert: nil,
                        resolve: nil
                    )
                case .ok:
                    return nil
                }
            }

        return result.sorted { $0.date > $1.date }
    }

    static func count(
        restaurantId: UUID,
        temperatureAlerts: [TemperatureAlert],
        cleaningCriticalities: [CleaningCriticality],
        defrostCriticalities: [DefrostCriticality],
        oilAlerts: [OilControlAlert],
        checklistAlerts: [ChecklistAlert],
        traceabilityRecords: [TraceabilityRecord],
        goodsReceipts: [GoodsReceivingRecord],
        productionLabels: [ProductionLabelRecord],
        soonThresholdDays: Int
    ) -> Int {
        build(
            restaurantId: restaurantId,
            temperatureAlerts: temperatureAlerts,
            cleaningCriticalities: cleaningCriticalities,
            defrostCriticalities: defrostCriticalities,
            oilAlerts: oilAlerts,
            checklistAlerts: checklistAlerts,
            traceabilityRecords: traceabilityRecords,
            goodsReceipts: goodsReceipts,
            productionLabels: productionLabels,
            soonThresholdDays: soonThresholdDays,
            resolveTemperature: { _ in },
            resolveCleaning: { _ in },
            resolveDefrost: { _ in },
            resolveOil: { _ in },
            resolveTraceabilityNC: { _ in },
            resolveGoodsNC: { _ in }
        ).count
    }

    // MARK: - Private

    private static func expiryAlerts(
        records: [TraceabilityRecord],
        soonThresholdDays: Int,
        now: Date = Date()
    ) -> [HACCPAlertCandidate] {
        records
            .filter { TraceabilityRecordSupport.isExpiryMonitored($0) }
            .filter { $0.productStatus == .available || $0.productStatus == .expired }
            .filter { ProductExpiryEvaluator.needsExpiryAttention($0, thresholdDays: soonThresholdDays, now: now) }
            .map { record in
                let days = record.expiryDate.map {
                    ProductExpiryEvaluator.daysUntilExpiry($0, now: now)
                }
                let severity: HACCPBadgeStyle = (days ?? 0) < 0 || days == 0 ? .nonConforme : .warning
                let detail: String
                if let days {
                    if days < 0 { detail = "Scaduto da \(abs(days)) giorni" }
                    else if days == 0 { detail = "Scade oggi" }
                    else { detail = "Scade tra \(days) giorni" }
                } else {
                    detail = "Verifica scadenza"
                }
                return HACCPAlertCandidate(
                    id: alertUUID(namespace: 0xA1, source: record.id),
                    module: "Scadenze",
                    icon: "calendar.badge.exclamationmark",
                    title: "\(record.productName) · \(record.lotCode.isEmpty ? "senza lotto" : record.lotCode)",
                    detail: detail,
                    date: record.expiryDate ?? record.receivedAt,
                    severity: severity,
                    navigationTarget: .expiryControl,
                    checklistAlert: nil,
                    resolve: nil
                )
            }
    }

    private static func alertUUID(namespace: UInt8, source: UUID) -> UUID {
        var bytes = source.uuid
        bytes.0 = namespace
        bytes.6 = (bytes.6 & 0x0F) | 0x40
        bytes.8 = (bytes.8 & 0x3F) | 0x80
        return UUID(uuid: bytes)
    }

    private static func checklistBadgeStyle(for severity: ChecklistAlertSeverity) -> HACCPBadgeStyle {
        switch severity {
        case .critical: return .nonConforme
        case .high, .warning: return .warning
        }
    }

    private static func temperatureBadgeStyle(for severity: TemperatureSeverity) -> HACCPBadgeStyle {
        switch severity {
        case .critical, .high: return .nonConforme
        case .warning: return .warning
        case .info: return .info
        }
    }
}
