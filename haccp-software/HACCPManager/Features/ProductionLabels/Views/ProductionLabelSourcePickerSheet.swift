//
//  ProductionLabelSourcePickerSheet.swift
//  Crea etichetta da modulo HACCP collegato.
//

import SwiftUI
import SwiftData

struct ProductionLabelSourcePickerSheet: View {
    let dataStore: ProductionLabelsDataStore
    let onSelect: (ProductionLabelDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var segment: SourceSegment = .traceability

    private let service = ProductionLabelsService()

    enum SourceSegment: String, CaseIterable {
        case traceability = "Tracciabilità"
        case goods = "Ricezione"
        case blast = "Abbattimento"
        case defrost = "Decongelamento"
        case production = "Produzioni"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Origine", selection: $segment) {
                    ForEach(SourceSegment.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    switch segment {
                    case .traceability:
                        ForEach(dataStore.traceabilityRecords) { item in
                            sourceRow(
                                title: item.productName,
                                subtitle: "Lotto \(item.lotCode) · \(item.supplier)",
                                icon: "archivebox.fill",
                                photoData: traceabilityPhotoData(for: item)
                            ) {
                                onSelect(service.draft(from: item))
                            }
                        }
                    case .goods:
                        ForEach(dataStore.goodsReceipts, id: \.id) { item in
                            sourceRow(
                                title: item.productNameSnapshot,
                                subtitle: item.supplierNameSnapshot,
                                icon: "shippingbox.fill",
                                photoData: item.photoData
                            ) {
                                onSelect(service.draft(from: item))
                            }
                        }
                    case .blast:
                        ForEach(dataStore.blastRecords) { item in
                            sourceRow(
                                title: item.productionNameSnapshot,
                                subtitle: item.productionCategorySnapshot,
                                icon: "wind.snow"
                            ) {
                                onSelect(service.draft(from: item))
                            }
                        }
                    case .defrost:
                        ForEach(dataStore.defrostRecords) { item in
                            sourceRow(
                                title: item.productName,
                                subtitle: item.method,
                                icon: "snowflake"
                            ) {
                                onSelect(service.draft(from: item))
                            }
                        }
                    case .production:
                        ForEach(dataStore.productions) { item in
                            sourceRow(title: item.name, subtitle: "Produzione", icon: "fork.knife") {
                                onSelect(service.draft(from: item))
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Da modulo HACCP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi", action: onCancel)
                }
            }
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

    private func sourceRow(
        title: String,
        subtitle: String,
        icon: String,
        photoData: Data? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
}
