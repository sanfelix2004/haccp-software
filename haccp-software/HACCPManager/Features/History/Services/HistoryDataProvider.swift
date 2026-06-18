import Foundation

private enum HistoryFormat {
    static func date(_ value: Date?) -> String {
        value?.formatted(date: .abbreviated, time: .omitted) ?? "—"
    }

    static func dateTime(_ value: Date?) -> String {
        value?.formatted(date: .abbreviated, time: .shortened) ?? "—"
    }

    static func temp(_ value: Double?) -> String {
        value.map { String(format: "%.1f °C", $0) } ?? "—"
    }

    static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.1f%%", $0) } ?? "—"
    }

    static func yesNo(_ value: Bool) -> String {
        value ? "Sì" : "No"
    }

    static func text(_ value: String?) -> String {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? "—" : clean
    }
}

protocol HistoryDataProvider {
    associatedtype Source
    func entries(from source: Source, restaurantId: UUID) -> [HistoryEntry]
}

struct GoodsReceivingHistoryProvider: HistoryDataProvider {
    func entries(from source: [GoodsReceipt], restaurantId: UUID) -> [HistoryEntry] {
        source.filter { $0.restaurantId == restaurantId }.map { receipt in
            let checklist = receipt.checklistResults
                .map { result in
                    var text = "\(result.item.rawValue): \(result.value.label)"
                    if let note = result.note, !note.isEmpty {
                        text += " (\(note))"
                    }
                    return text
                }
                .joined(separator: " · ")
            return HistoryEntry(
                id: "goods-\(receipt.id)",
                module: .goodsReceiving,
                title: receipt.productNameSnapshot,
                category: receipt.category.rawValue,
                status: receipt.status.label,
                operatorName: receipt.createdByNameSnapshot,
                date: receipt.receivedAt,
                details: [
                    .init(label: "Fornitore", value: HistoryFormat.text(receipt.supplierNameSnapshot)),
                    .init(label: "Lotto", value: HistoryFormat.text(receipt.lotNumber)),
                    .init(label: "Scadenza", value: HistoryFormat.date(receipt.expiryDate)),
                    .init(label: "Temperatura", value: HistoryFormat.temp(receipt.temperatureValue)),
                    .init(label: "Range", value: "\(HistoryFormat.temp(receipt.minAllowed)) / \(HistoryFormat.temp(receipt.maxAllowed))"),
                    .init(label: "Esito temperatura", value: receipt.temperatureStatus.label),
                    .init(label: "Checklist HACCP", value: checklist.isEmpty ? "—" : checklist),
                    .init(label: "Foto", value: HistoryFormat.yesNo(receipt.photoData != nil)),
                    .init(label: "Note", value: HistoryFormat.text(receipt.notes)),
                    .init(label: "Azione correttiva", value: HistoryFormat.text(receipt.correctiveAction))
                ],
                hasCriticality: receipt.status != .conforme
            )
        }
    }
}

struct TraceabilityHistoryProvider {
    func entries(records: [TraceabilityRecord], logs: [TraceabilityLog], restaurantId: UUID) -> [HistoryEntry] {
        let recordsById = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let recordEntries = records.filter { $0.restaurantId == restaurantId }.map { record in
            HistoryEntry(
                id: "trace-\(record.id)",
                module: .traceability,
                title: record.productName,
                category: record.productStatus.label,
                status: record.isNonCompliant ? "Non conforme" : record.productStatus.label,
                operatorName: record.createdByNameSnapshot,
                date: record.receivedAt,
                details: [
                    .init(label: "Lotto", value: record.lotCode),
                    .init(label: "Fornitore", value: HistoryFormat.text(record.supplier)),
                    .init(label: "Scadenza", value: HistoryFormat.date(record.expiryDate)),
                    .init(label: "Produzioni associate", value: HistoryFormat.text(record.productionReference)),
                    .init(label: "Non conformità", value: record.isNonCompliant ? HistoryFormat.text(record.nonComplianceNote) : "No"),
                    .init(label: "Azione correttiva", value: HistoryFormat.text(record.nonComplianceCorrectiveAction)),
                    .init(label: "Foto", value: HistoryFormat.yesNo(record.photoData != nil)),
                    .init(label: "Note", value: HistoryFormat.text(record.notes))
                ],
                hasCriticality: record.isNonCompliant || record.productStatus == .expired || record.productStatus == .rejected
            )
        }
        let eventEntries = logs.compactMap { log -> HistoryEntry? in
            guard let record = recordsById[log.receivedItemId], record.restaurantId == restaurantId else { return nil }
            let action = actionLabel(log.actionType)
            return HistoryEntry(
                id: "trace-log-\(log.id)",
                module: .traceability,
                title: "\(record.productName) · \(action)",
                category: "Evento",
                status: action,
                operatorName: log.operatorName,
                date: log.timestamp,
                details: [
                    .init(label: "Prodotto", value: record.productName),
                    .init(label: "Lotto", value: record.lotCode),
                    .init(label: "Fornitore", value: HistoryFormat.text(record.supplier)),
                    .init(label: "Evento", value: action),
                    .init(label: "Dettaglio", value: HistoryFormat.text(log.detail)),
                    .init(label: "Produzione collegata", value: log.productionId.map { String($0.uuidString.prefix(8)).uppercased() } ?? "—")
                ],
                hasCriticality: log.actionType == .nonCompliance || log.actionType == .expired || log.actionType == .rejected || log.actionType == .withdrawn
            )
        }
        return recordEntries + eventEntries
    }

    private func actionLabel(_ action: TraceabilityActionType) -> String {
        switch action {
        case .created: return "Creazione"
        case .linkedToProduction: return "Collegamento produzione"
        case .expired: return "Scadenza"
        case .rejected: return "Respinto"
        case .nonCompliance: return "Non conformità"
        case .withdrawn: return "Ritiro / scarto"
        }
    }
}

struct TemperatureHistoryProvider {
    func entries(records: [TemperatureRecord], legacyRecords: [FridgeCheckRecord], restaurantId: UUID) -> [HistoryEntry] {
        let current = records.filter { $0.restaurantId == restaurantId }.map { record in
            HistoryEntry(
                id: "temp-\(record.id)",
                module: .fridges,
                title: record.deviceName,
                category: record.status.label,
                status: record.status.label,
                operatorName: record.measuredByName,
                date: record.measuredAt,
                details: [
                    .init(label: "Dispositivo", value: record.deviceName),
                    .init(label: "Temperatura", value: HistoryFormat.temp(record.value)),
                    .init(label: "Range", value: "\(String(format: "%.1f", record.minAllowed)) / \(String(format: "%.1f", record.maxAllowed)) °C"),
                    .init(label: "Note", value: HistoryFormat.text(record.notes)),
                    .init(label: "Azione correttiva", value: HistoryFormat.text(record.correctiveAction))
                ],
                hasCriticality: record.status == .outOfRange || record.status == .critical
            )
        }
        let legacy = legacyRecords.filter { $0.restaurantId == restaurantId }.map { record in
            HistoryEntry(
                id: "fridge-legacy-\(record.id)",
                module: .fridges,
                title: record.deviceName,
                category: "Controllo",
                status: "Registrato",
                operatorName: record.createdByNameSnapshot,
                date: record.createdAt,
                details: [
                    .init(label: "Dispositivo", value: record.deviceName),
                    .init(label: "Note", value: HistoryFormat.text(record.notes))
                ],
                hasCriticality: false
            )
        }
        return current + legacy
    }
}

struct CleaningHistoryProvider: HistoryDataProvider {
    func entries(from source: [CleaningRecord], restaurantId: UUID) -> [HistoryEntry] {
        source.filter { $0.restaurantId == restaurantId && $0.outcome != .daFare }.map { record in
            HistoryEntry(
                id: "cleaning-\(record.id)",
                module: .cleaningControl,
                title: "\(record.areaName) · \(record.taskName)",
                category: record.areaName,
                status: record.outcome.label,
                operatorName: record.updatedByNameSnapshot,
                date: record.updatedAt,
                details: [
                    .init(label: "Area", value: record.areaName),
                    .init(label: "Task", value: record.taskName),
                    .init(label: "Esito", value: record.outcome.label),
                    .init(label: "Criticità", value: record.outcome == .nonPulito ? "Sì" : "No"),
                    .init(label: "Azione correttiva", value: HistoryFormat.text(record.correctiveAction)),
                    .init(label: "Note", value: HistoryFormat.text(record.notes))
                ],
                hasCriticality: record.outcome == .nonPulito
            )
        }
    }
}

struct BlastChillingHistoryProvider: HistoryDataProvider {
    func entries(from source: [BlastChillingRecord], restaurantId: UUID) -> [HistoryEntry] {
        source
            .filter { $0.restaurantId == restaurantId && $0.status != .inCorso }
            .map { record in
            let sortDate = record.endedAt ?? record.startedAt
            return HistoryEntry(
                id: "blast-\(record.id)",
                module: .blastChilling,
                title: record.productionNameSnapshot,
                category: record.productionCategorySnapshot,
                status: record.status.label,
                operatorName: record.createdByNameSnapshot,
                date: sortDate,
                details: [
                    .init(label: "Produzione", value: record.productionNameSnapshot),
                    .init(label: "Categoria", value: record.productionCategorySnapshot),
                    .init(label: "Temperatura iniziale", value: HistoryFormat.temp(record.initialTemperature)),
                    .init(label: "Temperatura finale", value: HistoryFormat.temp(record.finalTemperature)),
                    .init(label: "Target", value: HistoryFormat.temp(record.targetTemperature)),
                    .init(label: "Inizio", value: HistoryFormat.dateTime(record.startedAt)),
                    .init(label: "Fine", value: HistoryFormat.dateTime(record.endedAt)),
                    .init(label: "Durata", value: record.durationText),
                    .init(label: "Esito", value: record.status.label),
                    .init(label: "Azione correttiva", value: HistoryFormat.text(record.correctiveAction)),
                    .init(label: "Note", value: HistoryFormat.text(record.notes))
                ],
                hasCriticality: record.status == .nonConforme
            )
        }
    }
}

struct OilControlHistoryProvider: HistoryDataProvider {
    func entries(from source: [OilControlRecord], restaurantId: UUID) -> [HistoryEntry] {
        source.filter { $0.restaurantId == restaurantId }.map { record in
            HistoryEntry(
                id: "oil-\(record.id)",
                module: .oilControl,
                title: record.oilPointNameSnapshot,
                category: record.oilStatus.label,
                status: record.oilStatus.label,
                operatorName: record.createdByNameSnapshot,
                date: record.checkedAt,
                details: [
                    .init(label: "Punto olio", value: record.oilPointNameSnapshot),
                    .init(label: "Stato olio", value: record.oilStatus.label),
                    .init(label: "Composti polari", value: HistoryFormat.percent(record.effectivePolarCompoundsValue)),
                    .init(label: "Temperatura", value: HistoryFormat.temp(record.temperature)),
                    .init(label: "Azione effettuata", value: record.oilAction.label),
                    .init(label: "Note", value: HistoryFormat.text(record.notes))
                ],
                hasCriticality: record.oilStatus.isCritical
            )
        }
    }
}

struct ExpiryHistoryProvider {
    func entries(traceabilityRecords: [TraceabilityRecord], restaurantId: UUID) -> [HistoryEntry] {
        traceabilityRecords
            .filter { $0.restaurantId == restaurantId && ($0.expiryDate != nil || $0.productStatus == .expired) }
            .map { record in
                HistoryEntry(
                    id: "expiry-\(record.id)",
                    module: .expiryControl,
                    title: record.productName,
                    category: "Scadenza",
                    status: record.productStatus == .expired ? "Scaduto" : "Monitorato",
                    operatorName: record.createdByNameSnapshot,
                    date: record.expiryDate ?? record.receivedAt,
                    details: [
                        .init(label: "Prodotto", value: record.productName),
                        .init(label: "Lotto", value: record.lotCode),
                        .init(label: "Scadenza", value: HistoryFormat.date(record.expiryDate)),
                        .init(label: "Stato", value: record.productStatus.label),
                        .init(label: "Azione", value: record.productStatus == .expired ? "Registrare ritiro/scarto" : (record.productStatus == .used ? "Archiviato" : "Monitoraggio")),
                        .init(label: "Operatore", value: record.createdByNameSnapshot)
                    ],
                    hasCriticality: record.productStatus == .expired
                )
            }
    }
}
