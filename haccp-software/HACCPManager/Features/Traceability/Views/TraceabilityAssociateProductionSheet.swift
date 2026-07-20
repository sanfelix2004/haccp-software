import SwiftUI
import SwiftData

/// Stessa interfaccia «Scegli piatto» del flusso sessione lotti, per associare
/// uno o più alimenti già in «Da associare».
struct TraceabilityAssociateProductionSheet: View {
    let primaryRecords: [TraceabilityRecord]
    let restaurantId: UUID
    let productions: [Production]
    let categories: [ProductionCategory]
    let onConfirm: (_ production: Production, _ additionalRecordIds: Set<UUID>, _ dishPhoto: Data?) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext

    @State private var selectedProduction: Production?
    @State private var selectedCategoryId: UUID?
    @State private var productionSearchText = ""
    @State private var productionDishPhotoData: Data?
    @State private var showProductionDishCamera = false
    @State private var selectedReusedRecordIds: Set<UUID> = []
    @State private var showAddProduction = false
    @State private var productionShelfLifeDays = 3
    @StateObject private var productionDishCamera = FinalizeReceiptCameraViewModel()

    private var primaryIds: Set<UUID> {
        Set(primaryRecords.map(\.id))
    }

    private var filteredProductions: [Production] {
        var list = productions
        if let selectedCategoryId {
            list = list.filter { $0.categoryId == selectedCategoryId }
        }
        let q = productionSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.name.lowercased().contains(q) }
        }
        return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var totalIngredientCount: Int {
        primaryIds.union(selectedReusedRecordIds).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSummary

                    VStack(alignment: .leading, spacing: 6) {
                        Text("A quale piatto colleghi questa produzione?")
                            .font(theme.typography.headline)
                        Text("Gli alimenti selezionati verranno raggruppati sotto il piatto scelto. La foto del piatto è separata da quella degli alimenti in ingresso.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }

                    productionDishPhotoSection

                    TraceabilityIngredientReusePanel(
                        restaurantId: restaurantId,
                        sessionLottoIds: Set(primaryRecords.compactMap(\.lottoFotoId)),
                        selectedRecordIds: $selectedReusedRecordIds,
                        pinnedRecordIds: primaryIds,
                        startExpanded: true
                    )

                    Divider()

                    TraceabilityInlineSearchField(
                        placeholder: "Cerca piatto…",
                        text: $productionSearchText
                    )

                    HStack {
                        Spacer()
                        Button {
                            showAddProduction = true
                        } label: {
                            Label("Aggiungi piatto", systemImage: "plus.circle.fill")
                                .font(theme.typography.caption.weight(.semibold))
                        }
                    }

                    categoryTabs

                    if filteredProductions.isEmpty {
                        Text("Nessun piatto trovato.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    } else {
                        BlastChillingProductionGridView(
                            productions: filteredProductions,
                            selectedProductionId: selectedProduction?.id,
                            showsShelfLife: true,
                            onSelect: {
                                selectedProduction = $0
                                productionShelfLifeDays = $0.defaultShelfLifeDays
                            }
                        )
                    }
                }
                .padding()
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Scegli piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva tracciabilità") {
                        guard let production = selectedProduction else { return }
                        let extras = selectedReusedRecordIds.subtracting(primaryIds)
                        onConfirm(production, extras, productionDishPhotoData)
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedProduction == nil || totalIngredientCount == 0)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let production = selectedProduction {
                    HStack {
                        Image(systemName: "fork.knife")
                        Text(production.name)
                            .font(theme.typography.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(totalIngredientCount) alimenti")
                            .font(theme.typography.caption.weight(.semibold))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .onAppear {
                selectedReusedRecordIds = primaryIds
            }
            .navigationDestination(isPresented: $showAddProduction) {
                TraceabilityQuickAddProductionSheet(
                    restaurantId: restaurantId,
                    categories: categories,
                    existingProductions: productions,
                    suggestedName: productionSearchText,
                    onSaved: { production in
                        showAddProduction = false
                        selectedProduction = production
                        productionShelfLifeDays = production.defaultShelfLifeDays
                    },
                    onCancel: { showAddProduction = false },
                    onError: { _ in showAddProduction = false }
                )
            }
            .fullScreenCover(isPresented: $showProductionDishCamera) {
                productionDishCameraSheet
            }
        }
    }

    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(primaryRecords.count) alimenti da associare")
                .font(theme.typography.subheadline.weight(.semibold))
            ForEach(primaryRecords.prefix(4)) { record in
                Text("· \(record.productName)\(record.lotCode.isEmpty ? "" : " · Lotto \(record.lotCode)")")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            if primaryRecords.count > 4 {
                Text("· … e altri \(primaryRecords.count - 4)")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var productionDishPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foto piatto finito")
                .font(theme.typography.subheadline.weight(.semibold))
            Text("Opzionale — non riusa le foto degli alimenti scansionati.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            if let productionDishPhotoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: productionDishPhotoData,
                size: 88,
                zoomTitle: "Piatto finito"
               ) {
                HStack(spacing: 12) {
                    thumb
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Scatta di nuovo") { showProductionDishCamera = true }
                            .font(theme.typography.caption.weight(.semibold))
                        Button("Rimuovi") { self.productionDishPhotoData = nil }
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorError)
                    }
                }
            } else {
                Button {
                    showProductionDishCamera = true
                } label: {
                    Label("Scatta foto del piatto", systemImage: "camera.fill")
                        .font(theme.typography.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var categoryTabs: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            categoryChip(nil, title: "Tutte")
            ForEach(categories) { category in
                categoryChip(category.id, title: category.name)
            }
        }
    }

    private func categoryChip(_ id: UUID?, title: String) -> some View {
        Button {
            selectedCategoryId = id
        } label: {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(selectedCategoryId == id ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedCategoryId == id ? theme.colorPrimary : theme.colorDivider)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var productionDishCameraSheet: some View {
        NavigationStack {
            ZStack {
                FinalizeCameraSessionPreview(session: productionDishCamera.session, cameraViewModel: productionDishCamera)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    Button("Scatta") { productionDishCamera.capturePhoto() }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 28)
                }
            }
            .navigationTitle("Foto piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { showProductionDishCamera = false }
                }
            }
            .onAppear { productionDishCamera.start() }
            .onDisappear { productionDishCamera.stop() }
            .onReceive(productionDishCamera.$capturedPhotoData) { data in
                guard let data, !data.isEmpty else { return }
                productionDishCamera.resetCaptureBuffer()
                showProductionDishCamera = false
                productionDishPhotoData = data
            }
        }
    }
}
