//
//  ProductionLabelLinkMatcher.swift
//  Una etichetta per elemento HACCP collegato.
//

import Foundation

enum ProductionLabelLinkMatcher {

    static func hasSourceLink(_ draft: ProductionLabelDraft) -> Bool {
        draft.traceabilityRecordId != nil
            || draft.goodsReceiptId != nil
            || draft.blastChillingRecordId != nil
            || draft.defrostRecordId != nil
            || draft.productionId != nil
    }

    static func existingLabel(
        for draft: ProductionLabelDraft,
        in labels: [ProductionLabelRecord]
    ) -> ProductionLabelRecord? {
        labels.first { matches(label: $0, draft: draft) }
    }

    static func existingLabel(
        for item: ProductionLabelSourceItem,
        in labels: [ProductionLabelRecord]
    ) -> ProductionLabelRecord? {
        labels.first { matches(label: $0, item: item) }
    }

    static func matches(label: ProductionLabelRecord, draft: ProductionLabelDraft) -> Bool {
        if let id = draft.traceabilityRecordId, label.traceabilityRecordId == id { return true }
        if let id = draft.goodsReceiptId, label.goodsReceiptId == id { return true }
        if let id = draft.blastChillingRecordId, label.blastChillingRecordId == id { return true }
        if let id = draft.defrostRecordId, label.defrostRecordId == id { return true }
        if let id = draft.productionId, label.productionId == id {
            let draftLot = draft.lotCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let labelLot = (label.lotCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !draftLot.isEmpty, draftLot.caseInsensitiveCompare(labelLot) == .orderedSame {
                return true
            }
        }
        return false
    }

    static func matches(label: ProductionLabelRecord, item: ProductionLabelSourceItem) -> Bool {
        switch item {
        case .traceability(let record):
            if label.traceabilityRecordId == record.id { return true }
            if let goodsReceiptId = record.goodsReceiptId, label.goodsReceiptId == goodsReceiptId {
                return true
            }
            return false
        case .blast(let record):
            return label.blastChillingRecordId == record.id
        case .defrost(let record):
            return label.defrostRecordId == record.id
        }
    }

    static func matchesLinkedSource(_ label: ProductionLabelRecord, _ source: ProductionLabelLinkedSource) -> Bool {
        switch source {
        case .traceability:
            return label.sourceModule == .traceability || label.sourceModule == .goodsReceiving
        case .blastChilling:
            return label.sourceModule == .blastChilling || label.sourceModule == .production
        case .defrost:
            return label.sourceModule == .defrost
        }
    }

    static func pendingCount(
        for source: ProductionLabelLinkedSource,
        dataStore: ProductionLabelsDataStore,
        labels: [ProductionLabelRecord]
    ) -> Int {
        ProductionLabelSourceItem.items(for: source, dataStore: dataStore)
            .filter { existingLabel(for: $0, in: labels) == nil }
            .count
    }
}
