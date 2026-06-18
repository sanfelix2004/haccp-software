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

    let mode: Mode
    let restaurantId: UUID
    let user: LocalUser
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var draft: ProductionLabelDraft
    @State private var previewLabelId = UUID()
    @State private var linkedPhotoData: Data?
    @State private var errorMessage: String?

    private let service = ProductionLabelsService()

    init(
        mode: Mode,
        restaurantId: UUID,
        user: LocalUser,
        onSaved: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.restaurantId = restaurantId
        self.user = user
        self.onSaved = onSaved
        self.onCancel = onCancel
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
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    if let linkedPhotoData,
                       let preview = HACCPZoomablePhotoPreview(data: linkedPhotoData, height: 200, zoomTitle: draft.productName) {
                        DashboardCardView(title: "Foto prodotto", subtitle: "Da modulo HACCP collegato") {
                            preview
                        }
                    }

                    DashboardCardView(title: "Anteprima etichetta", subtitle: "Come apparirà l'adesivo HACCP") {
                        ProductionLabelStickerView(label: previewLabel, compact: false)
                    }

                    DashboardCardView(title: "Dati etichetta") {
                        VStack(spacing: 14) {
                            TextField("Nome prodotto *", text: $draft.productName)
                            TextField("Categoria", text: $draft.category)
                            TextField("Lotto", text: $draft.lotCode)
                            TextField("Fornitore", text: $draft.supplier)
                            DatePicker("Data produzione", selection: $draft.productionDate, displayedComponents: [.date, .hourAndMinute])
                            DatePicker("Data scadenza", selection: $draft.expiryDate, displayedComponents: [.date, .hourAndMinute])
                            TextField("Allergeni (separati da virgola)", text: $draft.allergens)
                            TextField("Conservazione", text: $draft.storageInstructions)
                            TextField("Temperatura", text: $draft.temperatureNote)
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

                    HStack {
                        Image(systemName: draft.sourceModule.icon)
                        Text("Origine: \(draft.sourceModule.label)")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Modifica etichetta" : "Nuova etichetta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
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

    private func save() {
        do {
            switch mode {
            case .create:
                _ = try service.create(draft: draft, restaurantId: restaurantId, user: user, modelContext: modelContext)
            case .edit(let label):
                try service.update(label, draft: draft, user: user, modelContext: modelContext)
            }
            onSaved()
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
