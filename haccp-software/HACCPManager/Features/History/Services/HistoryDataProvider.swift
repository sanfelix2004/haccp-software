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
                    .init(label: "Note", value: HistoryFormat.text(receipt.notes)),
                    .init(label: "Azione correttiva", value: HistoryFormat.text(receipt.correctiveAction))
                ],
                hasCriticality: receipt.status != .conforme,
                photoData: receipt.photoData
            )
        }
    }
}

struct TraceabilityHistoryProvider {
    func entries(
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        lottoProductionLinks: [LottoFotoProductionLink],
        lottoFotos: [LottoFoto],
        restaurantId: UUID
    ) -> [HistoryEntry] {
        let scopedRecords = records.filter {
            $0.restaurantId == restaurantId && TraceabilityRecordSupport.isHubRecord($0)
        }
        let recordsById = HACCPSafeParse.dictionary(scopedRecords.map { ($0.id, $0) })

        let hub = TraceabilityHubContext(
            records: scopedRecords,
            productions: productions,
            links: links,
            lottoProductionLinks: lottoProductionLinks,
            lottoFotos: lottoFotos
        )

        let productionGroups = hub.productionArchiveGroups(
            records: scopedRecords,
            filter: .all,
            searchText: ""
        )

        let linkedRecordIds = Set(productionGroups.flatMap { $0.ingredients.compactMap(\.recordId) })
        let productionEntries = productionGroups.compactMap { group -> HistoryEntry? in
            let ingredients = group.ingredients.compactMap { item -> HistoryTraceabilityIngredient? in
                guard let recordId = item.recordId,
                      let record = recordsById[recordId] else { return nil }
                return HistoryTraceabilityIngredient(
                    id: recordId,
                    name: item.name,
                    lotCode: item.lotCode,
                    supplier: item.supplier,
                    expiryText: HistoryFormat.date(record.expiryDate),
                    operatorName: record.createdByNameSnapshot,
                    hasCriticality: ingredientHasCriticality(record)
                )
            }
            guard !ingredients.isEmpty else { return nil }
            return HistoryEntry(
                id: "trace-prod-\(group.id)",
                module: .traceability,
                title: group.productionName,
                category: "Produzione registrata",
                status: TraceabilityCountLabel.alimenti(ingredients.count),
                operatorName: ingredients.first?.operatorName ?? "—",
                date: group.registeredAt,
                details: [
                    .init(label: "Piatto", value: group.productionName),
                    .init(label: "Ingredienti", value: TraceabilityCountLabel.alimenti(ingredients.count)),
                    .init(label: "Registrato", value: HistoryFormat.dateTime(group.registeredAt))
                ],
                hasCriticality: ingredients.contains(where: \.hasCriticality),
                traceabilityIngredients: ingredients
            )
        }

        let standaloneEntries = scopedRecords
            .filter { !linkedRecordIds.contains($0.id) }
            .map { record in
                let sourceLabel: String
                switch record.source {
                case .receipt: sourceLabel = "Ricezione merci"
                case .manual:
                    sourceLabel = record.lottoFotoId != nil ? "Lotto fotografato" : "Ingresso manuale"
                }
                return HistoryEntry(
                    id: "trace-lot-\(record.id)",
                    module: .traceability,
                    title: record.productName,
                    category: sourceLabel,
                    status: record.productStatus.label,
                    operatorName: record.createdByNameSnapshot,
                    date: record.receivedAt,
                    details: [
                        .init(label: "Prodotto", value: record.productName),
                        .init(label: "Lotto", value: HistoryFormat.text(record.lotCode.nilIfEmpty)),
                        .init(label: "Fornitore", value: HistoryFormat.text(record.supplier)),
                        .init(label: "Scadenza", value: HistoryFormat.date(record.expiryDate)),
                        .init(label: "Stato", value: record.productStatus.label),
                        .init(label: "Origine", value: sourceLabel)
                    ],
                    hasCriticality: ingredientHasCriticality(record)
                )
            }

        return productionEntries + standaloneEntries
    }

    func logEntries(
        logs: [TraceabilityLog],
        records: [TraceabilityRecord],
        productions: [Production],
        restaurantId: UUID
    ) -> [HistoryEntry] {
        let recordsById = HACCPSafeParse.dictionary(
            records.filter { $0.restaurantId == restaurantId }.map { ($0.id, $0) }
        )
        let productionsById = HACCPSafeParse.dictionary(productions.map { ($0.id, $0) })
        let meaningful: Set<TraceabilityActionType> = [.withdrawn, .nonCompliance, .rejected]

        return logs.compactMap { log -> HistoryEntry? in
            guard meaningful.contains(log.actionType),
                  let record = recordsById[log.receivedItemId] else { return nil }
            let actionLabel = logActionLabel(log.actionType, detail: log.detail)
            let productionName = log.linkedProductionDisplayName(productionsById: productionsById)
            var details: [HistoryEntryDetail] = [
                .init(label: "Prodotto", value: record.productName),
                .init(label: "Lotto", value: HistoryFormat.text(record.lotCode.nilIfEmpty)),
                .init(label: "Azione", value: actionLabel),
                .init(label: "Operatore", value: log.operatorName)
            ]
            if let productionName, !productionName.isEmpty {
                details.append(.init(label: "Produzione", value: productionName))
            }
            if let detail = log.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                details.append(.init(label: "Dettaglio", value: detail))
            }
            return HistoryEntry(
                id: "trace-log-\(log.id)",
                module: .traceability,
                title: "\(actionLabel) · \(record.productName)",
                category: "Timeline audit",
                status: actionLabel,
                operatorName: log.operatorName,
                date: log.timestamp,
                details: details,
                hasCriticality: log.actionType == .nonCompliance
                    || log.actionType == .rejected
            )
        }
    }

    private func logActionLabel(_ action: TraceabilityActionType, detail: String?) -> String {
        switch action {
        case .withdrawn:
            let trimmed = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.localizedCaseInsensitiveContains("scartat") {
                return TraceabilityWithdrawalKind.scartato.label
            }
            if trimmed.localizedCaseInsensitiveContains("usat")
                || trimmed.localizedCaseInsensitiveContains("ritirat") {
                return TraceabilityWithdrawalKind.ritirato.label
            }
            return trimmed.isEmpty ? "Chiusura lotto" : trimmed
        case .nonCompliance: return "Non conformità"
        case .rejected: return "Respinto"
        case .linkedToProduction: return "Associato a produzione"
        default: return action.rawValue
        }
    }

    private func ingredientHasCriticality(_ record: TraceabilityRecord) -> Bool {
        record.isNonCompliant || record.productStatus == .expired || record.productStatus == .rejected
    }
}

struct ChecklistHistoryProvider {
    private static let meaningfulStatuses: Set<ChecklistRunStatus> = [.completed, .failed, .missed, .archived]

    func entries(
        runs: [ChecklistRun],
        itemResults: [ChecklistItemResult],
        restaurantId: UUID
    ) -> [HistoryEntry] {
        let scopedRuns = runs.filter {
            $0.restaurantId == restaurantId && Self.meaningfulStatuses.contains($0.status)
        }
        let itemsByRunId = Dictionary(grouping: itemResults, by: \.checklistRunId)

        return scopedRuns.map { run in
            let items = (itemsByRunId[run.id] ?? []).sorted { $0.orderIndex < $1.orderIndex }
            let evaluatedItems = items.filter { $0.result != .pending }
            let passCount = evaluatedItems.filter { $0.result == .pass || $0.result == .notApplicable }.count
            let failCount = evaluatedItems.filter { $0.result == .fail }.count

            var details: [HistoryEntryDetail] = [
                .init(label: "Checklist", value: run.templateTitleSnapshot),
                .init(label: "Stato", value: run.status.label),
                .init(label: "Operatore", value: HistoryFormat.text(run.completedByNameSnapshot)),
                .init(label: "Avvio", value: HistoryFormat.dateTime(run.startedAt)),
                .init(label: "Completamento", value: HistoryFormat.dateTime(run.completedAt)),
                .init(label: "Scadenza prevista", value: HistoryFormat.dateTime(run.dueAt)),
                .init(label: "Progresso", value: "\(Int(run.progressPercentage.rounded()))%"),
                .init(label: "Esito voci", value: "\(passCount) OK · \(failCount) non OK · \(evaluatedItems.count) totali"),
                .init(label: "Note generali", value: HistoryFormat.text(run.notes))
            ]

            for item in evaluatedItems {
                var value = item.result.label
                if let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    value += " — \(note)"
                }
                details.append(.init(label: item.titleSnapshot, value: value))
            }

            return HistoryEntry(
                id: "checklist-run-\(run.id)",
                module: .checklist,
                title: run.templateTitleSnapshot,
                category: run.status == .failed || failCount > 0 ? "Con criticità" : "Registro completato",
                status: run.status.label,
                operatorName: HistoryFormat.text(run.completedByNameSnapshot),
                date: run.completedAt ?? run.startedAt,
                details: details,
                hasCriticality: run.status == .failed || failCount > 0
            )
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
    func entries(
        traceabilityRecords: [TraceabilityRecord],
        traceabilityLogs: [TraceabilityLog],
        lottoFotos: [LottoFoto],
        restaurantId: UUID
    ) -> [HistoryEntry] {
        let lottoById = Dictionary(lottoFotos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let logsByRecord = Dictionary(grouping: traceabilityLogs, by: \.receivedItemId)

        return traceabilityRecords
            .filter { $0.restaurantId == restaurantId && TraceabilityRecordSupport.isExpiryMonitored($0) }
            .compactMap { record -> HistoryEntry? in
                let sourceLabel = TraceabilityRecordSupport.expirySourceLabel(for: record, lottoById: lottoById)
                let logs = (logsByRecord[record.id] ?? []).sorted { $0.timestamp > $1.timestamp }

                if record.productStatus == .expired, record.canBeWithdrawn {
                    return HistoryEntry(
                        id: "expiry-pending-\(record.id)",
                        module: .expiryControl,
                        title: record.productName,
                        category: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                        status: "Da chiudere",
                        operatorName: record.createdByNameSnapshot,
                        date: record.expiryDate ?? record.receivedAt,
                        details: [
                            .init(label: "Tipo", value: TraceabilityRecordSupport.expiryTypeLabel(for: record)),
                            .init(label: "Prodotto", value: record.productName),
                            .init(label: "Lotto", value: record.lotCode),
                            .init(label: "Fornitore", value: HistoryFormat.text(record.supplier)),
                            .init(label: "Scadenza", value: HistoryFormat.date(record.expiryDate)),
                            .init(label: "Provenienza scadenza", value: HistoryFormat.text(sourceLabel)),
                            .init(label: "Azione richiesta", value: "Indica se il lotto è stato usato o scartato"),
                            .init(label: "Operatore", value: record.createdByNameSnapshot)
                        ],
                        hasCriticality: true,
                        pendingTraceabilityRecordId: record.id
                    )
                }

                guard record.productStatus == .used
                    || record.productStatus == .rejected
                    || record.isNonCompliant else { return nil }

                let closureStatus = closureStatusLabel(for: record, logs: logs)
                let anchorDate = logs.first(where: { $0.actionType == .withdrawn })?.timestamp
                    ?? record.expiryDate
                    ?? record.receivedAt

                return HistoryEntry(
                    id: "expiry-\(record.id)",
                    module: .expiryControl,
                    title: record.productName,
                    category: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                    status: closureStatus,
                    operatorName: logs.first(where: { $0.actionType == .withdrawn })?.operatorName
                        ?? record.createdByNameSnapshot,
                    date: anchorDate,
                    details: [
                        .init(label: "Tipo", value: TraceabilityRecordSupport.expiryTypeLabel(for: record)),
                        .init(label: "Prodotto", value: record.productName),
                        .init(label: "Lotto", value: record.lotCode),
                        .init(label: "Fornitore", value: HistoryFormat.text(record.supplier)),
                        .init(label: "Scadenza", value: HistoryFormat.date(record.expiryDate)),
                        .init(label: "Provenienza scadenza", value: HistoryFormat.text(sourceLabel)),
                        .init(label: "Esito operatore", value: closureStatus),
                        .init(label: "Operatore", value: logs.first(where: { $0.actionType == .withdrawn })?.operatorName
                            ?? record.createdByNameSnapshot)
                    ],
                    hasCriticality: record.productStatus == .rejected || record.isNonCompliant
                )
            }
    }

    private func closureStatusLabel(for record: TraceabilityRecord, logs: [TraceabilityLog]) -> String {
        if let withdrawn = logs.first(where: { $0.actionType == .withdrawn }) {
            let detail = withdrawn.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if detail.localizedCaseInsensitiveContains("scartat") {
                return TraceabilityWithdrawalKind.scartato.label
            }
            if detail.localizedCaseInsensitiveContains("usat")
                || detail.localizedCaseInsensitiveContains("ritirat") {
                return TraceabilityWithdrawalKind.ritirato.label
            }
            return detail.isEmpty ? TraceabilityWithdrawalKind.ritirato.label : detail
        }
        if record.productStatus == .rejected { return "Respinto" }
        if record.isNonCompliant { return "Non conforme" }
        return ProductStatus.used.label
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
