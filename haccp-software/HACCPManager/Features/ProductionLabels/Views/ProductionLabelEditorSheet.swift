//
//  ProductionLabelEditorSheet.swift
//

import SwiftUI
import SwiftData

struct ProductionLabelEditorSheet: View {
    enum Mode {
        case create(ProductionLabelDraft)
        case edit(ProductionLabelRecord)
    }

    enum EditorTab: String, CaseIterable, Identifiable {
        case preview = "Anteprima"
        case product = "Prodotto"
        case storage = "Conservazione"

        var id: String { rawValue }
    }

    let mode: Mode
    let restaurantId: UUID
    let user: LocalUser
    let onSaved: (ProductionLabelRecord, Bool) -> Void
    let onCancel: () -> Void
    var initialTab: EditorTab = .preview

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @ObservedObject private var printerManager = ClabelPrinterManager.shared
    @State private var draft: ProductionLabelDraft
    @State private var selectedTab: EditorTab
    @State private var previewLabelId = UUID()
    @State private var linkedPhotoData: Data?
    @State private var errorMessage: String?

    private let service = ProductionLabelsService()

    init(
        mode: Mode,
        restaurantId: UUID,
        user: LocalUser,
        initialTab: EditorTab = .preview,
        onSaved: @escaping (ProductionLabelRecord, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.restaurantId = restaurantId
        self.user = user
        self.initialTab = initialTab
        self.onSaved = onSaved
        self.onCancel = onCancel
        _selectedTab = State(initialValue: initialTab)
        switch mode {
        case .create(let initial):
            _draft = State(initialValue: initial)
        case .edit(let label):
            _draft = State(initialValue: ProductionLabelsService().draft(from: label))
        }
    }

    private var previewLabel: ProductionLabelRecord {
        ProductionLabelRecord(
            id: previewLabelId,
            restaurantId: restaurantId,
            productName: draft.productName.isEmpty ? "Anteprima prodotto" : draft.productName,
            productionDate: draft.productionDate,
            expiryDate: draft.expiryDate,
            lotCode: draft.lotCode.nilIfEmpty,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name,
            notes: draft.notes.nilIfEmpty,
            category: draft.category.nilIfEmpty,
            supplier: draft.supplier.nilIfEmpty,
            allergens: draft.allergens.nilIfEmpty,
            storageInstructions: draft.storageInstructions.nilIfEmpty,
            temperatureNote: draft.temperatureNote.nilIfEmpty,
            quantity: Double(draft.quantity.replacingOccurrences(of: ",", with: ".")),
            unit: draft.unit.nilIfEmpty,
            productStatus: draft.productStatus,
            sourceModule: draft.sourceModule,
            traceabilityRecordId: draft.traceabilityRecordId,
            goodsReceiptId: draft.goodsReceiptId,
            blastChillingRecordId: draft.blastChillingRecordId,
            defrostRecordId: draft.defrostRecordId,
            productionId: draft.productionId
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Scheda", selection: $selectedTab) {
                    ForEach(EditorTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, theme.spacing.screenPadding + 8)
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: theme.spacing.sectionSpacing) {
                        switch selectedTab {
                        case .preview:
                            previewTab
                        case .product:
                            productTab
                        case .storage:
                            storageTab
                        }

                        originFooter
                        printerHint
                    }
                    .padding(theme.spacing.screenPadding + 8)
                }
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Modifica etichetta" : "Nuova etichetta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if printerManager.isConnected {
                        Button("Salva e stampa") { save(andPrint: true) }
                            .disabled(!draft.isValid)
                    }
                    Button("Salva") { save(andPrint: false) }
                        .disabled(!draft.isValid)
                }
            }
            .alert("Etichette", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task(id: linkedPhotoTaskID) {
                linkedPhotoData = ProductionLabelImageResolver.imageData(
                    for: previewLabel,
                    context: modelContext
                )
            }
        }
    }

    @ViewBuilder
    private var previewTab: some View {
        if let linkedPhotoData,
           let preview = HACCPZoomablePhotoPreview(data: linkedPhotoData, height: 200, zoomTitle: draft.productName) {
            DashboardCardView(title: "Foto prodotto", subtitle: "Da modulo HACCP collegato") {
                preview
            }
        }

        DashboardCardView(title: "Anteprima etichetta", subtitle: "Come apparirà l'adesivo HACCP") {
            ProductionLabelStickerView(label: previewLabel, compact: false)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var productTab: some View {
        DashboardCardView(title: "Identificazione", subtitle: "Nome, lotto e date") {
            VStack(spacing: 14) {
                TextField("Nome prodotto *", text: $draft.productName)
                TextField("Categoria", text: $draft.category)
                TextField("Lotto", text: $draft.lotCode)
                TextField("Fornitore", text: $draft.supplier)
                DatePicker("Data produzione", selection: $draft.productionDate, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Data scadenza", selection: $draft.expiryDate, displayedComponents: [.date, .hourAndMinute])
            }
            .textFieldStyle(.roundedBorder)
        }

        DashboardCardView(title: "Allergeni", subtitle: "Separati da virgola") {
            TextField("Es. glutine, latte, uova…", text: $draft.allergens, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var storageTab: some View {
        DashboardCardView(title: "Conservazione e uso", subtitle: "Istruzioni per l'etichetta") {
            VStack(spacing: 14) {
                TextField("Conservazione", text: $draft.storageInstructions, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Temperatura (es. Ti -18 · Tf 3 · Dur 45m)", text: $draft.temperatureNote)
                HStack {
                    TextField("Quantità", text: $draft.quantity)
                        .keyboardType(.decimalPad)
                    TextField("Unità", text: $draft.unit)
                        .frame(width: 80)
                }
                Picker("Stato prodotto", selection: $draft.productStatus) {
                    ForEach(ProductionLabelProductStatus.allCases, id: \.self) { s in
                        Text(s.label).tag(s)
                    }
                }
                TextField("Note", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var originFooter: some View {
        HStack {
            Image(systemName: draft.sourceModule.icon)
            Text("Origine: \(draft.sourceModule.displayLabel)")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var printerHint: some View {
        if printerManager.isConnected {
            Text(printerManager.isReadyToPrint
                 ? "Dopo il salvataggio la stampa parte subito."
                 : "Stampante collegata: «Salva e stampa» accoda l’etichetta finché il canale non è pronto.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var linkedPhotoTaskID: String {
        [
            draft.traceabilityRecordId?.uuidString ?? "",
            draft.goodsReceiptId?.uuidString ?? "",
            draft.defrostRecordId?.uuidString ?? ""
        ].joined(separator: "|")
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func save(andPrint: Bool) {
        do {
            let record: ProductionLabelRecord
            switch mode {
            case .create:
                record = try service.create(draft: draft, restaurantId: restaurantId, user: user, modelContext: modelContext)
            case .edit(let label):
                try service.update(label, draft: draft, user: user, modelContext: modelContext)
                record = label
            }
            onSaved(record, andPrint)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
