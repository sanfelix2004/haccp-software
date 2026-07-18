import SwiftUI
import SwiftData

// MARK: - TraceabilityRecordHistoryDetailSheet
// Visualizza i dettagli completi di un singolo lotto di tracciabilità (ingrediente)
// all'interno dello storico. Risolve il requisito di poter cliccare sugli ingredienti
// per vedere maggiori info.

struct TraceabilityRecordHistoryDetailSheet: View {
    let recordId: UUID
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var record: TraceabilityRecord?
    @State private var photoData: Data?
    @State private var extraPhotos: [Data] = []
    @State private var linkedProductions: [Production] = []
    @State private var productionLotCode: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Caricamento dettagli lotto…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let record = record {
                    ScrollView {
                        VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                            headerBlock(record)
                            if let productionLotCode, !productionLotCode.isEmpty {
                                ProductionInternalLotBadge(batchCode: productionLotCode, compact: true)
                            }
                            infoCard(record)
                            
                            if record.isNonCompliant {
                                nonComplianceCard(record)
                            }
                            
                            if !linkedProductions.isEmpty {
                                productionsCard
                            }
                            
                            if let photo = photoData {
                                photoCard(photo, title: "Documentazione fotografica")
                            }
                            if !extraPhotos.isEmpty {
                                extraPhotosCard
                            }
                        }
                        .padding(theme.spacing.screenPadding + 8)
                    }
                } else {
                    DashboardEmptyStateView(state: .init(
                        title: "Lotto non trovato",
                        message: "Impossibile recuperare i dettagli di questo lotto nel database.",
                        actionTitle: nil
                    ))
                }
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle(record?.productName ?? "Dettaglio lotto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi", action: onDismiss)
                }
            }
            .task {
                loadData()
            }
        }
    }

    // MARK: - Data Loader

    private func loadData() {
        let targetId = recordId
        
        // 1. Fetch TraceabilityRecord
        var recordDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> { $0.id == targetId }
        )
        recordDescriptor.fetchLimit = 1
        guard let fetchedRecord = (try? modelContext.fetch(recordDescriptor))?.first else {
            isLoading = false
            return
        }
        self.record = fetchedRecord
        
        // 2. Fetch associated photos (ProductImage / inline / disco)
        var imageDescriptor = FetchDescriptor<ProductImage>(
            predicate: #Predicate<ProductImage> { !$0.isArchived }
        )
        let allImages = (try? modelContext.fetch(imageDescriptor)) ?? []
        let lottoFotos = (try? modelContext.fetch(FetchDescriptor<LottoFoto>())) ?? []
        let photos = ProductImageBytesResolver.allPhotos(
            record: fetchedRecord,
            images: allImages,
            lottoFotos: lottoFotos
        )
        self.photoData = photos.first
        if photos.count > 1 {
            // Conserva tutte le foto per la griglia sotto (prima già in photoData).
            extraPhotos = Array(photos.dropFirst())
        } else {
            extraPhotos = []
        }
        
        // 3. Fetch linked productions
        var linkDescriptor = FetchDescriptor<TraceabilityLink>(
            predicate: #Predicate<TraceabilityLink> { $0.receivedItemId == targetId }
        )
        let links = (try? modelContext.fetch(linkDescriptor)) ?? []
        let productionIds = Set(links.map(\.productionId))
        
        if !productionIds.isEmpty {
            let allProductions = (try? modelContext.fetch(FetchDescriptor<Production>())) ?? []
            self.linkedProductions = allProductions.filter { productionIds.contains($0.id) }
        }

        // 4. Lotto produzione (batch collegato o codice interno sul record)
        if let batchId = fetchedRecord.produzioneBatchId {
            var batchDescriptor = FetchDescriptor<ProduzioneBatch>(
                predicate: #Predicate<ProduzioneBatch> { $0.id == batchId }
            )
            batchDescriptor.fetchLimit = 1
            if let batch = (try? modelContext.fetch(batchDescriptor))?.first {
                productionLotCode = batch.batchCode
            }
        }
        if productionLotCode == nil {
            let links = (try? modelContext.fetch(FetchDescriptor<LottoFotoProductionLink>())) ?? []
            let matchingLinks = links.filter { link in
                if let lottoId = fetchedRecord.lottoFotoId {
                    return link.lottoFotoId == lottoId && link.produzioneBatchId != nil
                }
                return false
            }
            if let batchId = matchingLinks.compactMap(\.produzioneBatchId).first {
                var batchDescriptor = FetchDescriptor<ProduzioneBatch>(
                    predicate: #Predicate<ProduzioneBatch> { $0.id == batchId }
                )
                batchDescriptor.fetchLimit = 1
                productionLotCode = (try? modelContext.fetch(batchDescriptor))?.first?.batchCode
            }
        }
        if productionLotCode == nil,
           InternalLotCodeGenerator.isInternalLotCode(fetchedRecord.lotCode) {
            productionLotCode = fetchedRecord.lotCode
        }
        
        isLoading = false
    }

    // MARK: - Components

    private func headerBlock(_ record: TraceabilityRecord) -> some View {
        let isProductionLot = productionLotCode != nil
            || record.produzioneBatchId != nil
            || InternalLotCodeGenerator.isInternalLotCode(record.lotCode)
        return HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.colorPrimary.opacity(0.14))
                    .frame(width: 54, height: 54)
                Image(systemName: "shippingbox.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.colorPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.productName)
                    .font(theme.typography.title3.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                
                HStack(spacing: 8) {
                    Text(isProductionLot
                         ? "Lotto produzione \(record.lotCode)"
                         : "Lotto \(record.lotCode)")
                        .font(theme.typography.caption.weight(.bold).monospaced())
                        .foregroundStyle(theme.colorPrimary)
                    
                    HACCPBadge(
                        title: record.isNonCompliant ? "Non Conforme" : "Conforme",
                        style: record.isNonCompliant ? .nonConforme : .conforme,
                        showIcon: false
                    )
                }
            }
            Spacer()
        }
        .padding(16)
        .background(theme.colorSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    private func infoCard(_ record: TraceabilityRecord) -> some View {
        let isProductionLot = productionLotCode != nil
            || record.produzioneBatchId != nil
            || InternalLotCodeGenerator.isInternalLotCode(record.lotCode)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Informazioni generali")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
            
            VStack(spacing: 8) {
                if let productionLotCode, !productionLotCode.isEmpty {
                    infoRow(label: "Lotto produzione", value: productionLotCode, icon: "number")
                }
                if !isProductionLot || record.lotCode != (productionLotCode ?? "") {
                    infoRow(
                        label: isProductionLot ? "Lotto produzione" : "Lotto fornitore",
                        value: record.lotCode.isEmpty ? "—" : record.lotCode,
                        icon: "barcode"
                    )
                }
                infoRow(label: "Fornitore", value: record.supplier.isEmpty ? "—" : record.supplier, icon: "building.2")
                infoRow(label: "Data ricezione", value: record.receivedAt.formatted(date: .long, time: .shortened), icon: "calendar")
                if let expiry = record.expiryDate {
                    infoRow(label: "Data scadenza", value: expiry.formatted(date: .long, time: .omitted), icon: "calendar.badge.exclamationmark")
                }
                infoRow(label: "Registrato da", value: record.createdByNameSnapshot, icon: "person.fill")
            }
        }
        .padding(16)
        .background(theme.colorSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    private func nonComplianceCard(_ record: TraceabilityRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.colorError)
                Text("Dettagli Non Conformità")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Descrizione anomalia")
                        .font(theme.typography.caption2.weight(.bold))
                        .foregroundStyle(theme.colorTextSecondary)
                    Text(record.nonComplianceNote ?? "Nessuna nota specificata")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colorTextPrimary)
                }
                
                if let action = record.nonComplianceCorrectiveAction, !action.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Azione correttiva")
                            .font(theme.typography.caption2.weight(.bold))
                            .foregroundStyle(theme.colorTextSecondary)
                        Text(action)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colorTextPrimary)
                    }
                }
                
                Divider()
                HStack {
                    Text("Stato pratica:")
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorTextSecondary)
                    
                    if let resolvedAt = record.nonComplianceResolvedAt {
                        Text("Risolta il \(resolvedAt.formatted(date: .abbreviated, time: .shortened)) da \(record.nonComplianceResolvedByNameSnapshot ?? "—")")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorSuccess)
                    } else {
                        Text("Attiva / Non risolta")
                            .font(theme.typography.caption.weight(.bold))
                            .foregroundStyle(theme.colorError)
                    }
                }
            }
        }
        .padding(16)
        .background(theme.colorError.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .strokeBorder(theme.colorError.opacity(0.25), lineWidth: 1)
        )
    }

    private var productionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Utilizzato nelle produzioni (piatti)")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
            
            VStack(spacing: 8) {
                ForEach(linkedProductions) { production in
                    HStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .font(.caption)
                            .foregroundStyle(theme.colorPrimary)
                            .frame(width: 32, height: 32)
                            .background(theme.colorPrimary.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(production.name)
                                .font(theme.typography.subheadline.weight(.semibold))
                                .foregroundStyle(theme.colorTextPrimary)
                            Text("Registrato il \(production.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(theme.typography.caption2)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(theme.colorSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(theme.colorSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    private func photoCard(_ data: Data, title: String = "Foto allegata") -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            if let thumb = HACCPZoomablePhotoThumbnail(
                data: data,
                size: 220,
                zoomTitle: title
            ) {
                thumb
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(theme.colorSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    private var extraPhotosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Altre foto")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(extraPhotos.enumerated()), id: \.offset) { index, data in
                        if let thumb = HACCPZoomablePhotoThumbnail(
                            data: data,
                            size: 96,
                            zoomTitle: "Foto \(index + 2)"
                        ) {
                            thumb
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(theme.colorSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(theme.colorPrimary)
                .frame(width: 20)
            
            Text(label)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            
            Spacer()
            
            Text(value)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colorTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}
