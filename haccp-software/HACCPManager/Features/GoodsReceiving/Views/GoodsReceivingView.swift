import SwiftUI
import SwiftData
import AVFoundation
import Combine

struct GoodsReceivingView: View {
    @Environment(\.modelContext) private var modelContext
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
                    if scopedSuppliers.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessun fornitore configurato",
                            message: "Aggiungi un fornitore per iniziare",
                            actionTitle: nil
                        ))
                    }
                    VStack(spacing: 14) {
                        SupplierSelectionView(
                            suppliers: scopedSuppliers,
                            selectedSupplierId: vm.selectedSupplier?.id,
                            canManageSuppliers: isMaster,
                            onSelect: { vm.selectedSupplier = $0 },
                            onAdd: { if isMaster { showAddSupplier = true } },
                            onEdit: {
                                guard isMaster else { return }
                                guard let selected = vm.selectedSupplier else { return }
                                newSupplierName = selected.name
                                showEditSupplier = true
                            }
                        )
                        ProductCategoryTabsView(selectedCategory: $vm.selectedCategory)
                        ProductSelectionGridView(
                            products: filteredTemplates,
                            recentProductIds: vm.recentProductIds,
                            selectedProductId: vm.selectedProduct?.id,
                            onSelect: {
                                guard vm.selectedSupplier != nil else {
                                    vm.errorMessage = "Seleziona prima un fornitore."
                                    return
                                }
                                vm.setProduct($0)
                            }
                        )
                        HStack(spacing: 10) {
                            Button("Aggiungere") {}
                                .buttonStyle(.bordered)
                                .tint(.white)
                                .disabled(!isMaster)
                                .opacity(isMaster ? 1 : 0.4)
                            Button("Modifica") {}
                                .buttonStyle(.bordered)
                                .tint(.white)
                                .disabled(!isMaster || vm.selectedProduct == nil)
                                .opacity((isMaster && vm.selectedProduct != nil) ? 1 : 0.4)
                            Spacer()
                            Button("Annullare") {
                                vm.selectedProduct = nil
                                vm.selectedCategory = .all
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                            Button("Ho finito") {
                                guard let product = vm.selectedProduct else { return }
                                vm.setProduct(product)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint((vm.selectedProduct == nil || vm.selectedSupplier == nil) ? .gray : .green)
                            .disabled(vm.selectedProduct == nil || vm.selectedSupplier == nil)
                        }
                    }
                }

                DashboardCardView(title: "Storico ricezioni") {
                    if scopedRecords.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessuna ricezione registrata",
                            message: "Le registrazioni merci con conformita e note appariranno qui.",
                            actionTitle: nil
                        ))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(scopedRecords.prefix(20)) { record in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        if let data = record.photoData, let image = UIImage(data: data) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 54, height: 54)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.05))
                                                .frame(width: 54, height: 54)
                                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(record.productNameSnapshot).foregroundColor(.white)
                                            Text("Fornitore: \(record.supplierNameSnapshot)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text(record.status.label)
                                            .font(.caption.bold())
                                            .foregroundColor(record.status == .conforme ? .green : .orange)
                                    }

                                    HStack(spacing: 10) {
                                        infoPill("Categoria", record.category.rawValue)
                                        infoPill("Ricezione", record.receivedAt.formatted(date: .abbreviated, time: .shortened))
                                    }

                                    if let temperature = record.temperatureValue {
                                        let range = "(\(formatTemperature(record.minAllowed)) / \(formatTemperature(record.maxAllowed)))"
                                        Text("Temperatura: \(String(format: "%.1f", temperature))°C \(range) - \(record.temperatureStatus.label)")
                                            .font(.caption2)
                                            .foregroundColor(record.temperatureStatus == .conforme ? .gray : .yellow)
                                    }

                                    HStack(spacing: 10) {
                                        Text("Lotto: \(record.lotNumber?.isEmpty == false ? record.lotNumber! : "-")")
                                        Text("Scadenza: \(record.expiryDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")")
                                        Text("Produzione: \(record.productionDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.gray)

                                    HStack(spacing: 10) {
                                        Text("Quantita: \(record.quantity.map { String(format: "%.2f", $0) } ?? "-") \(record.unit ?? "")")
                                        Text("Operatore: \(record.createdByNameSnapshot.isEmpty ? "-" : record.createdByNameSnapshot)")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.gray)

                                    if !record.checklistResults.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Checklist HACCP")
                                                .font(.caption2.bold())
                                                .foregroundColor(.white.opacity(0.85))
                                            ForEach(record.checklistResults) { item in
                                                let note = (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                                Text("• \(item.item.rawValue): \(item.value.label)\(note.isEmpty ? "" : " (\(note))")")
                                                    .font(.caption2)
                                                    .foregroundColor(item.value == .notOk ? .orange : .gray)
                                            }
                                        }
                                    }

                                    if let notes = record.notes, !notes.isEmpty {
                                        Text("Note: \(notes)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    if let action = record.correctiveAction, !action.isEmpty {
                                        Text("Azione correttiva: \(action)")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                    }

                                    HStack {
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
                                        .tint(.white)
                                        Button("Elimina", role: .destructive) {
                                            deleteReceipt(record)
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    Text("Creato: \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Ricezione merci")
        .onAppear {
            guard let rid = appState.activeRestaurantId else { return }
            vm.loadMemory(restaurantId: rid)
            vm.selectedSupplier = scopedSuppliers.first(where: { $0.id == vm.lastSupplierId }) ?? scopedSuppliers.first
            vm.service.ensureDefaults(
                restaurantId: rid,
                suppliers: scopedSuppliers,
                templates: scopedTemplates,
                modelContext: modelContext
            )
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
                        .foregroundColor(.white)
                    Text(pendingRequiresMandatoryPhoto
                         ? "Foto obbligatoria per non conformità."
                         : "Aggiungi foto (opzionale). Puoi salvare senza foto se tutti i controlli sono conformi.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .frame(height: pendingRequiresMandatoryPhoto ? 220 : 160)
                        .overlay(
                            Group {
                                if finalizeCamera.authorizationDenied {
                                    VStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.gray)
                                        Text("Accesso fotocamera negato")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    FinalizeCameraSessionPreview(session: finalizeCamera.session)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                    HStack(spacing: 10) {
                        if !pendingRequiresMandatoryPhoto {
                            Button("Salva senza foto") {
                                finalizeReceipt(photoData: nil)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                        }
                        Button("Scatta foto") {
                            awaitingFinalizeCapture = true
                            finalizeCamera.capturePhoto()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(finalizeCamera.authorizationDenied)
                    }
                }
                .padding(24)
                .background(Color(hex: "#0A0A0A").ignoresSafeArea())
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
            guard awaitingFinalizeCapture, let data else { return }
            awaitingFinalizeCapture = false
            finalizePhotoData = data
            finalizeReceipt(photoData: data)
        }
        .alert("Ricezione merci", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Nuovo fornitore", isPresented: $showAddSupplier) {
            TextField("Nome fornitore", text: $newSupplierName)
            Button("Annulla", role: .cancel) {}
            Button("Salva") { addSupplier() }
        } message: {
            Text("Inserisci il nome del fornitore.")
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
    }

    private func addSupplier() {
        guard isMaster else { return }
        guard let rid = appState.activeRestaurantId else { return }
        let name = newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let supplier = Supplier(restaurantId: rid, name: name)
        modelContext.insert(supplier)
        try? modelContext.save()
        vm.selectedSupplier = supplier
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
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.07))
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
        record.temperatureValue = Double(editTemperatureText.replacingOccurrences(of: ",", with: "."))
        record.lotNumber = editLot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editLot
        record.expiryDate = editIncludeExpiry ? editExpiryDate : nil
        record.notes = editNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editNotes
        record.correctiveAction = editCorrectiveAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editCorrectiveAction
        syncTraceabilityFromReceipt(record)
        try? modelContext.save()
        editRecord = nil
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

            // Ricezione merci e la fonte: se la scadenza cambia, aggiorna anche lo stato in Tracciabilita.
            guard trace.productStatus != .rejected else { continue }
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
                DispatchQueue.global(qos: .userInitiated).async {
                    if self.session.isRunning == false {
                        self.session.startRunning()
                    }
                }
            }
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
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
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            connection.videoRotationAngle = 0
            return
        }
        switch scene.interfaceOrientation {
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
