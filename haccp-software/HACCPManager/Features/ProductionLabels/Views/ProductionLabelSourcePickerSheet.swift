//
//  ProductionLabelSourcePickerSheet.swift
//  Crea etichetta da modulo HACCP collegato — una scheda per origine.
//

import SwiftUI
import SwiftData

struct ProductionLabelSourcePickerSheet: View {
    let dataStore: ProductionLabelsDataStore
    var focusSource: ProductionLabelSource? = nil
    let onSelect: (ProductionLabelDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme

    enum SourceSegment: String, CaseIterable, Identifiable {
        case traceability = "Tracciabilità"
        case blast = "Abbattimento"
        case defrost = "Decongelamento"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .traceability: return "fork.knife"
            case .blast: return "wind.snow"
            case .defrost: return "snowflake"
            }
        }

        var subtitle: String {
            switch self {
            case .traceability: return "Piatti preparati dopo associazione lotti"
            case .blast: return "Abbattimenti completati"
            case .defrost: return "Decongelamenti completati"
            }
        }

        var sourceModule: ProductionLabelSource {
            switch self {
            case .traceability: return .traceability
            case .blast: return .blastChilling
            case .defrost: return .defrost
            }
        }

        init?(source: ProductionLabelSource) {
            switch source {
            case .traceability, .goodsReceiving: self = .traceability
            case .blastChilling, .production: self = .blast
            case .defrost: self = .defrost
            case .manual: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let focusSource, let segment = SourceSegment(source: focusSource) {
                    ProductionLabelSourceListView(
                        segment: segment,
                        dataStore: dataStore,
                        onSelect: onSelect
                    )
                } else {
                    sourceModuleList
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi", action: onCancel)
                }
            }
        }
    }

    private var navigationTitle: String {
        if let focusSource {
            return focusSource.tabTitle
        }
        return "Nuova etichetta"
    }

    private var sourceModuleList: some View {
        List {
            ForEach(SourceSegment.allCases) { segment in
                    NavigationLink {
                        ProductionLabelSourceListView(
                            segment: segment,
                            dataStore: dataStore,
                            onSelect: onSelect
                        )
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: segment.icon)
                                .font(.title3)
                                .foregroundStyle(theme.colorPrimary)
                                .frame(width: 40, height: 40)
                                .background(theme.colorPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(segment.rawValue)
                                    .font(theme.typography.headline)
                                    .foregroundStyle(theme.colorTextPrimary)
                                Text(segment.subtitle)
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colorTextSecondary)
                            }

                            Spacer(minLength: 8)

                            Text("\(itemCount(for: segment))")
                                .font(theme.typography.subheadline.weight(.semibold))
                                .foregroundStyle(theme.colorTextSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.colorDivider.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
    }

    private func itemCount(for segment: SourceSegment) -> Int {
        switch segment {
        case .traceability: return dataStore.traceabilityRecords.count
        case .blast: return dataStore.blastRecords.count
        case .defrost: return dataStore.defrostRecords.count
        }
    }
}

private struct ProductionLabelSourceListView: View {
    let segment: ProductionLabelSourcePickerSheet.SourceSegment
    let dataStore: ProductionLabelsDataStore
    let onSelect: (ProductionLabelDraft) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    private let service = ProductionLabelsService()

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nessun elemento",
                    systemImage: segment.icon,
                    description: Text(emptyMessage)
                )
            } else {
                List(items, id: \.id) { item in
                    Button {
                        onSelect(draft(for: item))
                    } label: {
                        sourceRow(for: item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(segment.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyMessage: String {
        switch segment {
        case .traceability: return "Non ci sono piatti preparati da etichettare. Associa i lotti in ingresso a un piatto in Tracciabilità."
        case .blast: return "Non ci sono abbattimenti completati."
        case .defrost: return "Non ci sono decongelamenti completati."
        }
    }

    private var items: [AnyHashableSourceItem] {
        switch segment {
        case .traceability:
            return dataStore.traceabilityRecords
                .filter(TraceabilityRecordSupport.isLabelTraceabilitySource)
                .map { .traceability($0) }
        case .blast:
            return dataStore.blastRecords.map { .blast($0) }
        case .defrost:
            return dataStore.defrostRecords.map { .defrost($0) }
        }
    }

    private func draft(for item: AnyHashableSourceItem) -> ProductionLabelDraft {
        switch item {
        case .traceability(let record): return service.draft(from: record)
        case .blast(let record): return service.draft(from: record)
        case .defrost(let record): return service.draft(from: record)
        }
    }

    @ViewBuilder
    private func sourceRow(for item: AnyHashableSourceItem) -> some View {
        switch item {
        case .traceability(let record):
            let source = TraceabilityRecordSupport.expirySourceLabel(for: record) ?? "Produzione finita"
            sourceRowContent(
                title: record.productName,
                subtitle: "Batch \(record.lotCode) · \(source)",
                icon: segment.icon,
                photoData: traceabilityPhotoData(for: record)
            )
        case .blast(let record):
            sourceRowContent(
                title: record.productionNameSnapshot,
                subtitle: record.productionCategorySnapshot,
                icon: segment.icon
            )
        case .defrost(let record):
            sourceRowContent(
                title: record.productName,
                subtitle: record.method,
                icon: segment.icon
            )
        }
    }

    private func traceabilityPhotoData(for item: TraceabilityRecord) -> Data? {
        var probe = ProductionLabelRecord(
            restaurantId: item.restaurantId,
            productName: item.productName,
            productionDate: item.receivedAt,
            expiryDate: item.expiryDate ?? item.receivedAt,
            createdByUserId: item.createdByUserId,
            createdByNameSnapshot: item.createdByNameSnapshot,
            traceabilityRecordId: item.id,
            goodsReceiptId: item.goodsReceiptId
        )
        return ProductionLabelImageResolver.imageData(for: probe, context: modelContext)
    }

    private func sourceRowContent(
        title: String,
        subtitle: String,
        icon: String,
        photoData: Data? = nil
    ) -> some View {
        HStack(spacing: 12) {
            if let photoData,
               let thumb = HACCPZoomablePhotoThumbnail(data: photoData, size: 40, zoomTitle: title) {
                thumb
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: icon)
                    .foregroundStyle(theme.colorPrimary)
                    .frame(width: 40, height: 40)
                    .background(theme.colorPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(theme.colorTextPrimary)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
    }
}

private enum AnyHashableSourceItem: Identifiable {
    case traceability(TraceabilityRecord)
    case blast(BlastChillingRecord)
    case defrost(DefrostRecord)

    var id: UUID {
        switch self {
        case .traceability(let r): return r.id
        case .blast(let r): return r.id
        case .defrost(let r): return r.id
        }
    }
}
