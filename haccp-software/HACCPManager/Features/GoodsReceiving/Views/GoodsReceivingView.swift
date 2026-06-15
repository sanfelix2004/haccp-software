import SwiftUI
import SwiftData
@preconcurrency import AVFoundation
import Combine

struct GoodsReceivingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var records: [GoodsReceipt]
    @Query private var suppliers: [Supplier]
    @Query private var templates: [ProductTemplate]
    @Query private var traceabilityRecords: [TraceabilityRecord]
    @Query private var traceabilityLinks: [TraceabilityLink]
    @Query private var traceabilityLogs: [TraceabilityLog]
    @Query private var productImages: [ProductImage]
    @StateObject private var vm = GoodsReceivingViewModel()
    @StateObject private var controlVM = GoodsReceiptControlViewModel()
    @State private var showAddSupplier = false
    @State private var showEditSupplier = false
    @State private var newSupplierName = ""
    @State private var editRecord: GoodsReceipt?
    @State private var editReceivedAt = Date()
    @State private var editTemperatureText = ""
    @State private var editLot = ""
    @State private var editIncludeExpiry = false
    @State private var editExpiryDate = Date()
    @State private var editNotes = ""
    @State private var editCorrectiveAction = ""
    @State private var editProductName = ""
    @State private var editSupplierId: UUID?
    @State private var editCategory: GoodsCategory = .refrigerated
    @State private var showFinalizePhotoSheet = false
    @State private var finalizePhotoData: Data?
    @State private var awaitingFinalizeCapture = false
    @StateObject private var finalizeCamera = FinalizeReceiptCameraViewModel()
    @State private var pendingSaveProduct: ProductTemplate?
    @State private var pendingSaveRequirement: GoodsReceiptRequirement?
    @State private var showMasterAuthDeleteReceipt = false
    @State private var receiptPendingDeletion: GoodsReceipt?
    @State private var labelDraft: ProductionLabelDraft?

    private let labelService = ProductionLabelsService()

    private var scopedRecords: [GoodsReceipt] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    private var scopedSuppliers: [Supplier] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return suppliers.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    private var scopedTemplates: [ProductTemplate] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return templates.filter { $0.restaurantId == rid }
    }
    private var filteredTemplates: [ProductTemplate] {
        let byCategory = vm.selectedCategory == .all ? scopedTemplates : scopedTemplates.filter { $0.category == vm.selectedCategory }
        return byCategory.sorted(by: { lhs, rhs in
            let lRecent = vm.recentProductIds.contains(lhs.id)
            let rRecent = vm.recentProductIds.contains(rhs.id)
            if lRecent != rRecent { return lRecent && !rRecent }
            return lhs.name < rhs.name
        })
    }
    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }
    private var isMaster: Bool { currentUser?.role == .master }
    private var selectedRequirement: GoodsReceiptRequirement? {
        guard let product = vm.selectedProduct else { return nil }
        return vm.service.requirementService.makeRequirement(for: product)
    }

    /// Dopo "Ho finito": se checklist/temperatura indicano non conformità, la foto diventa obbligatoria.
    private var pendingRequiresMandatoryPhoto: Bool {
        guard let requirement = pendingSaveRequirement else { return false }
        return vm.service.validationService.hasNonCompliance(
            requirement: requirement,
            checklistResults: controlVM.checklistResults,
            temperatureValue: controlVM.temperatureValue
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DashboardCardView(title: "Ricezione merci") {
                    VStack(spacing: 14) {
                        SupplierSelectionView(
                            suppliers: scopedSuppliers,
                            selectedSupplierId: vm.selectedSupplier?.id,
                            canAddSupplier: appState.activeRestaurantId != nil,
                            canEditSupplier: isMaster,
                            onSelect: { vm.selectedSupplier = $0 },
                            onAdd: { showAddSupplier = true },
                            onEdit: {
                                guard isMaster else { return }
                                guard let selected = vm.selectedSupplier else { return }
                                newSupplierName = selected.name
                                showEditSupplier = true
                            }
                        )
                        ProductCategoryTabsView(selectedCategory: $vm.selectedCategory)
                        if filteredTemplates.isEmpty {
                            DashboardEmptyStateView(state: .init(
                                title: "Nessun prodotto template",
                                message: "I template verranno creati automaticamente. Torna tra un attimo o riapri la schermata.",
                                actionTitle: nil
                            ))
                        } else {
                            ProductSelectionGridView(
                                products: filteredTemplates,
                                recentProductIds: vm.recentProductIds,
                                selectedProductId: vm.selectedProduct?.id,
                                onSelect: { vm.selectProductTemplate($0) }
                            )
                        }
                        HStack(spacing: 10) {
                            Button {
                                showAddSupplier = true
                            } label: {
                                Label("Aggiungi fornitore", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .tint(theme.colorPrimary)
                            .disabled(appState.activeRestaurantId == nil)
                            .opacity(appState.activeRestaurantId != nil ? 1 : 0.4)

                            if vm.selectedProduct != nil {
                                Button {
                                    vm.selectedProduct = nil
                                    vm.selectedCategory = .all
                                } label: {
                                    Label("Annulla", systemImage: "xmark")
                                }
                                .buttonStyle(.bordered)
                                .tint(theme.colorTextSecondary)
                            }

                            Spacer()

                            Button {
                                guard vm.selectedSupplier != nil else {
                                    vm.errorMessage = "Seleziona o aggiungi un fornitore prima di confermare la ricezione."
                                    return
                                }
                                guard vm.selectedProduct != nil else { return }
                                vm.presentControlSheet()
                            } label: {
                                Label("Conferma", systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint((vm.selectedProduct == nil || vm.selectedSupplier == nil) ? theme.colorTextSecondary : theme.colorSuccess)
                            .disabled(vm.selectedProduct == nil || vm.selectedSupplier == nil)
                        }
                    }
                }

                DashboardCardView(title: "Storico ricezioni") {
                    if scopedRecords.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessuna ricezione registrata",
                            message: "Le registrazioni merci con conformità e note appariranno qui.",
                            actionTitle: nil
                        ))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(scopedRecords.prefix(20)) { record in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        if let data = record.photoData,
                                           let thumb = HACCPZoomablePhotoThumbnail(data: data, size: 54, zoomTitle: record.productNameSnapshot) {
                                            thumb
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(ThemeManager.shared.colorSurface)
                                                .frame(width: 54, height: 54)
                                                .overlay(Image(systemName: "photo").foregroundStyle(ThemeManager.shared.colorTextSecondary))
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(record.productNameSnapshot).foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                            Text("Fornitore: \(record.supplierNameSnapshot)")
                                                .font(.caption)
                                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                        }
                                        Spacer()
                                        HACCPBadge(
                                            title: record.status.label,
                                            style: record.status == .conforme ? .conforme : .warning,
                                            showIcon: false
                                        )
                                    }

                                    HStack(spacing: 10) {
                                        infoPill("Categoria", record.category.rawValue)
                                        infoPill("Ricezione", record.receivedAt.formatted(date: .abbreviated, time: .shortened))
                                    }

                                    if let temperature = record.temperatureValue {
                                        let range = "(\(formatTemperature(record.minAllowed)) / \(formatTemperature(record.maxAllowed)))"
                                        Text("Temperatura: \(String(format: "%.1f", temperature))°C \(range) - \(record.temperatureStatus.label)")
                                            .font(.caption2)
                                            .foregroundStyle(record.temperatureStatus == .conforme ? theme.colorTextSecondary : theme.colorWarning)
                                    }

                                    HStack(spacing: 10) {
                                        Text("Lotto: \(record.lotNumber?.isEmpty == false ? record.lotNumber! : "-")")
                                        Text("Scadenza: \(record.expiryDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")")
                                        Text("Produzione: \(record.productionDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")")
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)

                                    HStack(spacing: 10) {
                                        Text("Quantità: \(record.quantity.map { String(format: "%.2f", $0) } ?? "-") \(record.unit ?? "")")
                                        Text("Operatore: \(record.createdByNameSnapshot.isEmpty ? "-" : record.createdByNameSnapshot)")
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)

                                    if !record.checklistResults.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Checklist HACCP")
                                                .font(.caption2.bold())
                                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                            ForEach(record.checklistResults) { item in
                                                let note = (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                                Text("• \(item.item.rawValue): \(item.value.label)\(note.isEmpty ? "" : " (\(note))")")
                                                    .font(.caption2)
                                                    .foregroundStyle(item.value == .notOk ? theme.colorWarning : theme.colorTextSecondary)
                                            }
                                        }
                                    }

                                    if let notes = record.notes, !notes.isEmpty {
                                        Text("Note: \(notes)")
                                            .font(.caption2)
                                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                    }
                                    if let action = record.correctiveAction, !action.isEmpty {
                                        Text("Azione correttiva: \(action)")
                                            .font(.caption2)
                                            .foregroundStyle(ThemeManager.shared.colorWarning)
                                    }

                                    HStack {
                                        CreateProductionLabelLink {
                                            labelDraft = labelService.draft(from: record)
                                        }
                                        Spacer()
                                        Button("Modifica") {
                                            editRecord = record
                                            editProductName = record.productNameSnapshot
                                            editSupplierId = record.supplierId ?? scopedSuppliers.first(where: { $0.name == record.supplierNameSnapshot })?.id
                                            editCategory = record.category
                                            editReceivedAt = record.receivedAt
                                            editTemperatureText = record.temperatureValue.map { String(format: "%.1f", $0) } ?? ""
                                            editLot = record.lotNumber ?? ""
                                            editIncludeExpiry = record.expiryDate != nil
                                            editExpiryDate = record.expiryDate ?? Date()
                                            editNotes = record.notes ?? ""
                                            editCorrectiveAction = record.correctiveAction ?? ""
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(ThemeManager.shared.colorPrimary)
                                        if isMaster {
                                            Button("Elimina", role: .destructive) {
                                                receiptPendingDeletion = record
                                                showMasterAuthDeleteReceipt = true
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }

                                    Text("Creato: \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundStyle(theme.colorTextSecondary.opacity(0.8))
                                }
                                .padding(10)
                                .background(ThemeManager.shared.colorSurface)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Ricezione merci")
        .onAppear {
            bootstrapReceivingSession()
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            bootstrapReceivingSession()
        }
        .sheet(isPresented: $vm.showControlSheet) {
            if let product = vm.selectedProduct, let requirement = selectedRequirement {
                GoodsReceiptControlSheet(
                    product: product,
                    requirement: requirement,
                    vm: controlVM,
                    isConfirmEnabled: canConfirm(requirement: requirement),
                    onCancel: {
                        vm.showControlSheet = false
                    },
                    onConfirm: {
                        prepareFinalizeSave(product: product, requirement: requirement)
                    }
                )
                .onAppear {
                    controlVM.bootstrap(requirement: requirement)
                }
            }
        }
        .sheet(isPresented: $showFinalizePhotoSheet) {
            NavigationStack {
                VStack(spacing: 14) {
                    Text("Foto ricezione")
                        .font(.title3.bold())
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    Text(pendingRequiresMandatoryPhoto
                         ? "Foto obbligatoria per non conformità."
                         : "Aggiungi foto (opzionale). Puoi salvare senza foto se tutti i controlli sono conformi.")
                        .font(.subheadline)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        .multilineTextAlignment(.center)
                    if let data = finalizePhotoData, let preview = HACCPZoomablePhotoPreview(data: data, height: pendingRequiresMandatoryPhoto ? 280 : 240, zoomTitle: "Foto ricezione") {
                        preview
                        HStack(spacing: 10) {
                            Button("Riscatta") {
                                finalizePhotoData = nil
                                finalizeCamera.resetCaptureBuffer()
                                finalizeCamera.start()
                            }
                            .buttonStyle(.bordered)
                            Button("Usa foto") {
                                finalizeReceipt(photoData: data)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.colorSuccess)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeManager.shared.colorCameraPreviewBackground)
                            .frame(height: pendingRequiresMandatoryPhoto ? 220 : 160)
                            .overlay(
                                Group {
                                    if finalizeCamera.authorizationDenied {
                                        VStack(spacing: 6) {
                                            Image(systemName: "camera.fill")
                                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                            Text("Accesso fotocamera negato")
                                                .font(.caption)
                                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                        }
                                    } else {
                                        FinalizeCameraSessionPreview(session: finalizeCamera.session)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ThemeManager.shared.colorDivider, lineWidth: 1)
                            )

                        HStack(spacing: 10) {
                            if !pendingRequiresMandatoryPhoto {
                                Button("Salva senza foto") {
                                    finalizeReceipt(photoData: nil)
                                }
                                .buttonStyle(.bordered)
                                .tint(ThemeManager.shared.colorPrimary)
                            }
                            Button("Scatta foto") {
                                awaitingFinalizeCapture = true
                                finalizeCamera.capturePhoto()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.colorSuccess)
                            .disabled(finalizeCamera.authorizationDenied)
                        }
                    }
                }
                .padding(24)
                .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") {
                            showFinalizePhotoSheet = false
                            pendingSaveProduct = nil
                            pendingSaveRequirement = nil
                            finalizePhotoData = nil
                            finalizeCamera.stop()
                        }
                    }
                }
                .onAppear {
                    finalizePhotoData = nil
                    finalizeCamera.resetCaptureBuffer()
                    awaitingFinalizeCapture = false
                    finalizeCamera.start()
                }
                .onDisappear {
                    awaitingFinalizeCapture = false
                    finalizeCamera.stop()
                }
            }
        }
        .onReceive(finalizeCamera.$capturedPhotoData) { data in
            guard awaitingFinalizeCapture, let data, !data.isEmpty else { return }
            awaitingFinalizeCapture = false
            finalizePhotoData = data
            finalizeCamera.stop()
        }
        .alert("Ricezione merci", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .sheet(isPresented: $showAddSupplier) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Nome fornitore", text: $newSupplierName)
                            .textInputAutocapitalization(.words)
                    } footer: {
                        Text("Il fornitore è salvato per questo ristorante e sarà subito selezionabile.")
                    }
                }
                .navigationTitle("Nuovo fornitore")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") {
                            newSupplierName = ""
                            showAddSupplier = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") {
                            addSupplier()
                            showAddSupplier = false
                        }
                        .disabled(newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Modifica fornitore", isPresented: $showEditSupplier) {
            TextField("Nome fornitore", text: $newSupplierName)
            Button("Annulla", role: .cancel) {}
            Button("Salva") { editSupplier() }
        } message: {
            Text("Aggiorna il nome del fornitore.")
        }
        .sheet(isPresented: Binding(get: { editRecord != nil }, set: { if !$0 { editRecord = nil } })) {
            NavigationStack {
                Form {
                    Section("Modifica ricezione") {
                        TextField("Nome prodotto", text: $editProductName)
                        Picker("Fornitore", selection: $editSupplierId) {
                            ForEach(scopedSuppliers, id: \.id) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                        Picker("Categoria", selection: $editCategory) {
                            ForEach(GoodsCategory.allCases.filter { $0 != .all }, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        DatePicker("Momento", selection: $editReceivedAt)
                        TextField("Temperatura (°C)", text: $editTemperatureText)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Lotto", text: $editLot)
                        Toggle("Scadenza", isOn: $editIncludeExpiry)
                        if editIncludeExpiry {
                            DatePicker("Data scadenza", selection: $editExpiryDate, displayedComponents: .date)
                        }
                        TextField("Note", text: $editNotes, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("Azione correttiva", text: $editCorrectiveAction, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") { editRecord = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") { saveEditedReceipt() }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { labelDraft != nil },
            set: { if !$0 { labelDraft = nil } }
        )) {
            if let draft = labelDraft,
               let rid = appState.activeRestaurantId,
               let user = currentUser {
                ProductionLabelEditorSheet(
                    mode: .create(draft),
                    restaurantId: rid,
                    user: user,
                    onSaved: { labelDraft = nil },
                    onCancel: { labelDraft = nil }
                )
            }
        }
        .fullScreenCover(isPresented: $showMasterAuthDeleteReceipt) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .deleteTraceabilityEntry,
                    onAuthorized: {
                        showMasterAuthDeleteReceipt = false
                        if let receipt = receiptPendingDeletion {
                            deleteReceipt(receipt)
                        }
                        receiptPendingDeletion = nil
                    },
                    onCancel: {
                        showMasterAuthDeleteReceipt = false
                        receiptPendingDeletion = nil
                    }
                ) { EmptyView() }
            }
        }
    }

    private func bootstrapReceivingSession() {
        guard let rid = appState.activeRestaurantId else { return }
        ProductTemplateSeeder.ensureTemplates(restaurantId: rid, modelContext: modelContext)
        vm.loadMemory(restaurantId: rid)
        vm.selectedSupplier = scopedSuppliers.first(where: { $0.id == vm.lastSupplierId }) ?? scopedSuppliers.first
    }

    private func addSupplier() {
        guard let rid = appState.activeRestaurantId else { return }
        let name = newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let supplier = Supplier(restaurantId: rid, name: name)
        modelContext.insert(supplier)
        try? modelContext.save()
        vm.selectedSupplier = supplier
        vm.persistMemory(restaurantId: rid)
        newSupplierName = ""
    }

    private func editSupplier() {
        guard isMaster else { return }
        guard let selected = vm.selectedSupplier else { return }
        let name = newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        selected.name = name
        try? modelContext.save()
        newSupplierName = ""
    }

    private func prepareFinalizeSave(product: ProductTemplate, requirement: GoodsReceiptRequirement) {
        pendingSaveProduct = product
        pendingSaveRequirement = requirement
        finalizePhotoData = nil
        vm.showControlSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showFinalizePhotoSheet = true
        }
    }

    private func finalizeReceipt(photoData: Data?) {
        guard let product = pendingSaveProduct, let requirement = pendingSaveRequirement else {
            showFinalizePhotoSheet = false
            return
        }
        let mandatory = vm.service.validationService.hasNonCompliance(
            requirement: requirement,
            checklistResults: controlVM.checklistResults,
            temperatureValue: controlVM.temperatureValue
        )
        if mandatory && (photoData == nil || photoData?.isEmpty == true) {
            vm.errorMessage = "Per una non conformità è obbligatorio allegare una foto."
            return
        }
        saveReceipt(product: product, requirement: requirement, photoData: photoData)
        showFinalizePhotoSheet = false
        pendingSaveProduct = nil
        pendingSaveRequirement = nil
    }

    private func saveReceipt(product: ProductTemplate, requirement: GoodsReceiptRequirement, photoData: Data?) {
        guard let rid = appState.activeRestaurantId, let user = currentUser, let supplier = vm.selectedSupplier else {
            vm.errorMessage = "Seleziona fornitore e prodotto."
            return
        }
        let temperature = controlVM.temperatureValue
        let validation = vm.service.validationService.validate(
            requirement: requirement,
            checklistResults: controlVM.checklistResults,
            temperatureValue: temperature,
            lotNumber: controlVM.lotNumber,
            hasExpiryDate: controlVM.includeExpiryDate,
            notes: controlVM.notes,
            correctiveAction: controlVM.correctiveAction,
            photoData: photoData,
            enforcePhotoIfNonCompliant: true
        )
        guard validation.canSubmit else {
            vm.errorMessage = validation.message ?? "Controlla i dati obbligatori."
            return
        }

        do {
            try vm.service.saveReceipt(
                restaurantId: rid,
                supplier: supplier,
                product: product,
                receivedAt: controlVM.receivedAt,
                temperature: temperature,
                lotCode: controlVM.lotNumber.isEmpty ? nil : controlVM.lotNumber,
                expiryDate: controlVM.includeExpiryDate ? controlVM.expiryDate : nil,
                productionDate: controlVM.includeProductionDate ? controlVM.productionDate : nil,
                quantity: controlVM.quantityValue,
                unit: controlVM.unit.isEmpty ? nil : controlVM.unit,
                checklistResults: controlVM.checklistResults,
                photoData: photoData,
                notes: controlVM.notes.isEmpty ? nil : controlVM.notes,
                correctiveAction: controlVM.correctiveAction.isEmpty ? nil : controlVM.correctiveAction,
                user: user,
                modelContext: modelContext
            )
            vm.persistMemory(restaurantId: rid)
            vm.resetForNext()
            vm.errorMessage = validation.message
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    private func canConfirm(requirement: GoodsReceiptRequirement) -> Bool {
        vm.service.validationService.validate(
            requirement: requirement,
            checklistResults: controlVM.checklistResults,
            temperatureValue: controlVM.temperatureValue,
            lotNumber: controlVM.lotNumber,
            hasExpiryDate: controlVM.includeExpiryDate,
            notes: controlVM.notes,
            correctiveAction: controlVM.correctiveAction,
            photoData: nil,
            enforcePhotoIfNonCompliant: false
        ).canSubmit
    }

    private func infoPill(_ title: String, _ value: String) -> some View {
        Text("\(title): \(value)")
            .font(.caption2)
            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ThemeManager.shared.colorSurfaceElevated)
            .cornerRadius(8)
    }

    private func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.1f°C", value)
    }

    private func saveEditedReceipt() {
        guard let record = editRecord else { return }
        let name = editProductName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { record.productNameSnapshot = name }
        if let sid = editSupplierId, let supplier = scopedSuppliers.first(where: { $0.id == sid }) {
            record.supplierId = supplier.id
            record.supplierNameSnapshot = supplier.name
        }
        record.category = editCategory
        record.receivedAt = editReceivedAt
        let temperature = Double(editTemperatureText.replacingOccurrences(of: ",", with: "."))
        record.temperatureValue = temperature
        record.lotNumber = trimmedOrNil(editLot)
        record.expiryDate = editIncludeExpiry ? editExpiryDate : nil
        record.notes = trimmedOrNil(editNotes)
        record.correctiveAction = trimmedOrNil(editCorrectiveAction)
        let status = recomputedReceiptStatus(for: record)
        if status.requiresDetails && (record.notes == nil || record.correctiveAction == nil) {
            vm.errorMessage = "Per una ricezione non conforme servono note e azione correttiva."
            return
        }
        record.temperatureStatus = status.temperatureStatus
        record.status = status.receiptStatus
        syncTraceabilityFromReceipt(record)
        try? modelContext.save()
        editRecord = nil
    }

    private func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func recomputedReceiptStatus(for record: GoodsReceipt) -> (receiptStatus: GoodsReceiptStatus, temperatureStatus: GoodsReceiptStatus, requiresDetails: Bool) {
        let tempOut = isReceiptTemperatureOutOfRange(record)
        let hasChecklistNotOk = record.checklistResults.contains { $0.value == .notOk }
        if hasChecklistNotOk {
            return (.nonConforme, tempOut ? .acceptedWithNotes : .conforme, true)
        }
        if tempOut {
            return (.acceptedWithNotes, .acceptedWithNotes, true)
        }
        return (.conforme, .conforme, false)
    }

    private func isReceiptTemperatureOutOfRange(_ record: GoodsReceipt) -> Bool {
        guard let value = record.temperatureValue else { return false }
        if let min = record.minAllowed, value < min { return true }
        if let max = record.maxAllowed, value > max { return true }
        return false
    }

    private func syncTraceabilityFromReceipt(_ receipt: GoodsReceipt) {
        let relatedTraceability = traceabilityRecords.filter { $0.goodsReceiptId == receipt.id }
        let now = Date()
        for trace in relatedTraceability {
            trace.productName = receipt.productNameSnapshot
            trace.supplier = receipt.supplierNameSnapshot
            trace.lotCode = receipt.lotNumber ?? ""
            trace.receivedAt = receipt.receivedAt
            trace.expiryDate = receipt.expiryDate
            trace.notes = receipt.notes
            trace.photoData = receipt.photoData
            trace.operatorSignature = receipt.createdByNameSnapshot
            trace.categoryRaw = receipt.categoryRaw
            trace.goodsReceiptStatusRaw = receipt.status.rawValue

            if receipt.status == .nonConforme || receipt.status == .rejected {
                trace.isNonCompliant = true
                trace.nonComplianceNote = receipt.notes
                trace.nonComplianceCorrectiveAction = receipt.correctiveAction
                trace.productStatus = .rejected
                continue
            }

            // Ricezione merci e la fonte: se la scadenza cambia, aggiorna anche lo stato in Tracciabilita.
            guard trace.isNonCompliant == false && trace.productStatus != .rejected else { continue }
            let isExpiredNow = (receipt.expiryDate?.timeIntervalSince(now) ?? 1) < 0
            if isExpiredNow {
                trace.productStatus = .expired
            } else if trace.productStatus == .expired {
                trace.productStatus = .available
            }
        }
    }

    private func deleteReceipt(_ receipt: GoodsReceipt) {
        let relatedTraceability = traceabilityRecords.filter { $0.goodsReceiptId == receipt.id }

        for trace in relatedTraceability {
            traceabilityLinks
                .filter { $0.receivedItemId == trace.id }
                .forEach { modelContext.delete($0) }
            traceabilityLogs
                .filter { $0.receivedItemId == trace.id }
                .forEach { modelContext.delete($0) }
            productImages
                .filter { $0.receivedItemId == trace.id }
                .forEach { modelContext.delete($0) }
            modelContext.delete(trace)
        }

        modelContext.delete(receipt)
        try? modelContext.save()
    }
}

@MainActor
final class FinalizeReceiptCameraViewModel: ObservableObject {
    let session = AVCaptureSession()
    @Published var authorizationDenied = false
    @Published var capturedPhotoData: Data?

    func resetCaptureBuffer() {
        capturedPhotoData = nil
    }

    private var configured = false
    private let photoOutput = AVCapturePhotoOutput()
    private var photoDelegate: FinalizeReceiptPhotoCaptureDelegate?

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.authorizationDenied = !granted
                guard granted else { return }
                self.configureIfNeeded()
                let session = self.session
                DispatchQueue.global(qos: .userInitiated).async {
                    if session.isRunning == false {
                        session.startRunning()
                    }
                }
            }
        }
    }

    func stop() {
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        defer {
            session.commitConfiguration()
            configured = true
        }
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
    }

    func capturePhoto() {
        guard session.isRunning else { return }
        let settings = AVCapturePhotoSettings()
        let delegate = FinalizeReceiptPhotoCaptureDelegate { [weak self] data in
            DispatchQueue.main.async { self?.capturedPhotoData = data }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
}

final class FinalizeReceiptPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            completion(nil)
            return
        }
        completion(photo.fileDataRepresentation())
    }
}

struct FinalizeCameraSessionPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> FinalizePreviewView {
        let view = FinalizePreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        view.videoPreviewLayer.connection?.isVideoMirrored = false
        applyOrientation(on: view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: FinalizePreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.videoPreviewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        uiView.videoPreviewLayer.connection?.isVideoMirrored = false
        applyOrientation(on: uiView.videoPreviewLayer)
    }

    private func applyOrientation(on layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection else { return }
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            connection.videoRotationAngle = 180
        case .landscapeRight:
            connection.videoRotationAngle = 0
        case .portraitUpsideDown:
            connection.videoRotationAngle = 270
        default:
            connection.videoRotationAngle = 90
        }
    }
}

final class FinalizePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
