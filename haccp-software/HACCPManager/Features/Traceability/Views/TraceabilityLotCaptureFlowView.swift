import SwiftUI
import SwiftData

/// Fotografa etichette in sequenza, assegna un Alimento Produzione, salva e stampa.
struct TraceabilityLotCaptureFlowView: View {
    let restaurantId: UUID
    let user: LocalUser
    var restaurantName: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @Query private var productions: [Production]
    @Query private var categories: [ProductionCategory]
    @Query private var suppliers: [Supplier]

    @StateObject private var camera = FinalizeReceiptCameraViewModel()

    @State private var sessionId = UUID()
    @State private var sessionItems: [LottoFoto] = []
    @State private var isSavingPhoto = false
    @State private var showProductionPicker = false
    @State private var showAddProduction = false
    @State private var productionSearchText = ""
    @State private var selectedProduction: Production?
    @State private var selectedProductionCategoryId: UUID?
    @State private var showDiscardAlert = false
    @State private var errorMessage: String?
    @State private var completedBatch: ProduzioneBatch?
    @State private var isPrinting = false
    @State private var selectedSupplier: Supplier?
    @State private var showSupplierPicker = false
    @State private var showAddSupplier = false
    @State private var newSupplierName = ""

    private let lottoService = LottoFotoService()
    private let labelService = ProductionLabelsService()

    init(
        restaurantId: UUID,
        user: LocalUser,
        restaurantName: String? = nil
    ) {
        self.restaurantId = restaurantId
        self.user = user
        self.restaurantName = restaurantName
        let rid = restaurantId
        _productions = Query(
            filter: #Predicate<Production> { $0.restaurantId == rid },
            sort: [SortDescriptor(\Production.name)]
        )
        _categories = Query(
            filter: #Predicate<ProductionCategory> { $0.restaurantId == rid },
            sort: [SortDescriptor(\ProductionCategory.orderIndex)]
        )
        _suppliers = Query(
            filter: #Predicate<Supplier> { $0.restaurantId == rid },
            sort: [SortDescriptor(\Supplier.name)]
        )
    }

    private var scopedProductions: [Production] {
        productions
            .filter { $0.restaurantId == restaurantId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var scopedCategories: [ProductionCategory] {
        categories
            .filter { $0.restaurantId == restaurantId }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var scopedSuppliers: [Supplier] {
        suppliers
            .filter { $0.restaurantId == restaurantId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var canManageSuppliers: Bool {
        user.permissions.can(.manageSuppliers)
    }

    private var categoryFilteredProductions: [Production] {
        guard let selectedProductionCategoryId else { return scopedProductions }
        return scopedProductions.filter { $0.categoryId == selectedProductionCategoryId }
    }

    private var filteredProductions: [Production] {
        let query = productionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categoryFilteredProductions }
        return categoryFilteredProductions.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            if completedBatch == nil {
                FullScreenLotCameraView(
                    camera: camera,
                    isProcessing: isSavingPhoto,
                    processingMessage: "Salvataggio foto…",
                    sessionPhotoCount: sessionItems.count,
                    onCapture: { camera.capturePhoto() }
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            if completedBatch == nil {
                VStack {
                    captureHeader
                    Spacer()
                        .allowsHitTesting(false)
                    if !sessionItems.isEmpty {
                        TraceabilitySessionDock(
                            items: sessionItems,
                            onFinish: presentProductionPicker,
                            onDelete: deletePhoto
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 108)
                    }
                }
            }

            if let batch = completedBatch {
                printOverlay(for: batch)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: beginCaptureSession)
        .onDisappear { camera.stop() }
        .onReceive(camera.$capturedPhotoData) { data in
            guard let data, !data.isEmpty, !isSavingPhoto, completedBatch == nil else { return }
            camera.resetCaptureBuffer()
            savePhoto(data)
        }
        .sheet(isPresented: $showProductionPicker, onDismiss: resumeCameraIfNeeded) {
            productionPickerSheet
        }
        .sheet(isPresented: $showSupplierPicker, onDismiss: resumeCameraIfNeeded) {
            supplierPickerSheet
        }
        .alert("Nuovo fornitore", isPresented: $showAddSupplier) {
            TextField("Nome fornitore", text: $newSupplierName)
            Button("Annulla", role: .cancel) {
                newSupplierName = ""
            }
            Button("Aggiungi") {
                commitAddSupplier()
            }
        } message: {
            Text("Stesso catalogo di Ricezione merci.")
        }
        .alert("Tracciabilità", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Scartare le foto?", isPresented: $showDiscardAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina foto", role: .destructive) {
                discardSessionPhotos()
            }
        } message: {
            Text("Hai \(sessionItems.count) foto non ancora collegate a un Alimento Produzione. Verranno eliminate.")
        }
    }

    // MARK: - Header

    private var captureHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if sessionItems.isEmpty {
                    Color.clear.frame(width: 36, height: 36)
                } else {
                    Button {
                        showDiscardAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scarta le foto")
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tracciabilità")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Text(sessionItems.isEmpty ? "Fotografa le etichette" : "\(sessionItems.count) etichette")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.45))
                .clipShape(Capsule())
            }

            Button {
                camera.stop()
                showSupplierPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.caption.weight(.semibold))
                    Text(selectedSupplier.map { "Fornitore: \($0.name)" } ?? "Fornitore (opzionale)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                selectedSupplier.map { "Fornitore \($0.name)" } ?? "Scegli fornitore opzionale"
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 52)
    }

    // MARK: - Picker fornitore (stesso catalogo Ricezione merci)

    private var supplierPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedSupplier = nil
                        TraceabilitySupplierMemory.clear(restaurantId: restaurantId)
                        showSupplierPicker = false
                    } label: {
                        HStack {
                            Text("Nessun fornitore")
                            Spacer()
                            if selectedSupplier == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.colorPrimary)
                            }
                        }
                    }
                } footer: {
                    Text("Opzionale. Se lo indichi, vale per le prossime foto di questa sessione. Stessi fornitori di Ricezione merci.")
                }

                Section("Fornitori") {
                    if scopedSuppliers.isEmpty {
                        Text("Nessun fornitore in catalogo. Aggiungilo qui o in Ricezione merci.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    } else {
                        ForEach(scopedSuppliers) { supplier in
                            Button {
                                selectedSupplier = supplier
                                TraceabilitySupplierMemory.remember(id: supplier.id, restaurantId: restaurantId)
                                showSupplierPicker = false
                            } label: {
                                HStack {
                                    Text(supplier.name)
                                        .foregroundStyle(theme.colorTextPrimary)
                                    Spacer()
                                    if selectedSupplier?.id == supplier.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(theme.colorPrimary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fornitore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { showSupplierPicker = false }
                }
                if canManageSuppliers {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            newSupplierName = ""
                            showAddSupplier = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Nuovo fornitore")
                    }
                }
            }
        }
    }

    private var productionPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A quale Alimento Produzione colleghi queste etichette?")
                            .font(theme.typography.headline)
                        Text("La durata è quella configurata sull’alimento: la scadenza si calcola da oggi.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }

                    TraceabilitySessionSummaryStrip(items: sessionItems)

                    TraceabilityInlineSearchField(
                        placeholder: "Cerca alimento produzione…",
                        text: $productionSearchText
                    )

                    HStack {
                        Spacer()
                        Button {
                            showAddProduction = true
                        } label: {
                            Label("Nuovo alimento", systemImage: "plus.circle.fill")
                                .font(theme.typography.caption.weight(.semibold))
                        }
                    }

                    productionCategoryTabs

                    if filteredProductions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nessun Alimento Produzione trovato.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                            if !productionSearchText.isEmpty {
                                Button("Aggiungi «\(productionSearchText)»") {
                                    showAddProduction = true
                                }
                                .font(theme.typography.caption.weight(.semibold))
                            }
                        }
                    } else {
                        BlastChillingProductionGridView(
                            productions: filteredProductions,
                            selectedProductionId: selectedProduction?.id,
                            showsShelfLife: true,
                            onSelect: { selectedProduction = $0 }
                        )
                    }

                    if let production = selectedProduction {
                        durationPreview(for: production)
                    }
                }
                .padding()
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Alimento Produzione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Altre foto") { showProductionPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva produzione") {
                        if let production = selectedProduction {
                            saveProduction(production)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedProduction == nil)
                }
            }
            .sheet(isPresented: $showAddProduction) {
                TraceabilityQuickAddProductionSheet(
                    restaurantId: restaurantId,
                    categories: scopedCategories,
                    existingProductions: scopedProductions,
                    suggestedName: productionSearchText,
                    onSaved: { production in
                        showAddProduction = false
                        selectedProduction = production
                        productionSearchText = ""
                    },
                    onCancel: { showAddProduction = false }
                )
            }
        }
    }

    private var productionCategoryTabs: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            productionCategoryButton(nil, title: "Tutte")
            ForEach(scopedCategories) { category in
                productionCategoryButton(category.id, title: category.name)
            }
        }
    }

    private func productionCategoryButton(_ id: UUID?, title: String) -> some View {
        Button {
            selectedProductionCategoryId = id
        } label: {
            Text(title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(selectedProductionCategoryId == id ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedProductionCategoryId == id ? theme.colorPrimary : theme.colorDivider)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func durationPreview(for production: Production) -> some View {
        let days = production.defaultShelfLifeDays
        let expiry = ScadenzaCalculator.productionExpiryDate(fromDays: days, referenceDate: Date())
        return VStack(alignment: .leading, spacing: 8) {
            Text(production.name)
                .font(theme.typography.headline)
            Text("Durata: \(days) \(days == 1 ? "giorno" : "giorni")")
                .font(theme.typography.subheadline.weight(.semibold))
            Text("Scadenza: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                .font(theme.typography.subheadline)
            Text("Recuperata dall’Alimento Produzione, non va reinserita.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorPrimary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Stampa immediata

    private func printOverlay(for batch: ProduzioneBatch) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.colorSuccess)
            Text("Produzione salvata")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            VStack(spacing: 6) {
                Text(batch.productionNameSnapshot)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                if let days = batch.shelfLifeDaysSnapshot {
                    Text("Durata: \(days) \(days == 1 ? "giorno" : "giorni")")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                if let expiry = batch.internalExpiryAt {
                    Text("Scadenza: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Button {
                printLabel(for: batch)
            } label: {
                HStack(spacing: 12) {
                    if isPrinting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "printer.fill")
                            .font(.title2.weight(.bold))
                    }
                    Text("STAMPA ETICHETTA")
                        .font(.title3.weight(.heavy))
                        .tracking(0.6)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(theme.colorPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isPrinting)
            .padding(.horizontal, 24)

            Button("Scatta altre etichette") {
                startFreshSession()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92).ignoresSafeArea())
    }

    // MARK: - Azioni

    private func beginCaptureSession() {
        restoreLastSupplier()
        if let open = lottoService.openSessions(restaurantId: restaurantId, modelContext: modelContext).first {
            let items = lottoService.unlinkedPhotos(
                sessionId: open.id,
                restaurantId: restaurantId,
                modelContext: modelContext
            )
            if !items.isEmpty {
                sessionId = open.id
                sessionItems = items
            }
        }
        camera.resetCaptureBuffer()
        camera.start()
    }

    private func restoreLastSupplier() {
        guard let id = TraceabilitySupplierMemory.lastUsedId(for: restaurantId) else {
            selectedSupplier = nil
            return
        }
        selectedSupplier = scopedSuppliers.first { $0.id == id }
    }

    private func commitAddSupplier() {
        let name = newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canManageSuppliers, !name.isEmpty else { return }
        let supplier = Supplier(restaurantId: restaurantId, name: name)
        modelContext.insert(supplier)
        do {
            try modelContext.save()
            selectedSupplier = supplier
            TraceabilitySupplierMemory.remember(id: supplier.id, restaurantId: restaurantId)
            newSupplierName = ""
            showAddSupplier = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePhoto(_ data: Data) {
        isSavingPhoto = true
        defer { isSavingPhoto = false }
        do {
            let lotto = try lottoService.confirmLabelPhoto(
                photoData: data,
                sessionId: sessionId,
                restaurantId: restaurantId,
                user: user,
                modelContext: modelContext,
                supplier: selectedSupplier?.name ?? ""
            )
            sessionItems.append(lotto)
            if let supplier = selectedSupplier {
                TraceabilitySupplierMemory.remember(id: supplier.id, restaurantId: restaurantId)
            }
            HapticManager.shared.trigger(.light)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePhoto(_ lotto: LottoFoto) {
        do {
            try lottoService.delete(lotto, modelContext: modelContext)
            sessionItems.removeAll { $0.id == lotto.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func discardSessionPhotos() {
        for item in sessionItems {
            try? lottoService.delete(item, modelContext: modelContext)
        }
        sessionItems = []
        sessionId = UUID()
    }

    private func presentProductionPicker() {
        guard !sessionItems.isEmpty else { return }
        selectedProduction = nil
        selectedProductionCategoryId = nil
        productionSearchText = ""
        camera.stop()
        showProductionPicker = true
    }

    private func resumeCameraIfNeeded() {
        guard completedBatch == nil else { return }
        camera.resetCaptureBuffer()
        camera.start()
    }

    private func saveProduction(_ production: Production) {
        do {
            let batch = try lottoService.completeKitchenSession(
                lottoFotos: sessionItems,
                production: production,
                user: user,
                modelContext: modelContext
            )
            showProductionPicker = false
            selectedProduction = production
            sessionItems = []
            sessionId = UUID()
            completedBatch = batch
            camera.stop()
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func printLabel(for batch: ProduzioneBatch) {
        isPrinting = true
        let production = scopedProductions.first { $0.id == batch.productionId } ?? selectedProduction
        var draft = labelService.draft(from: batch, production: production)
        let batchId = batch.id
        var outputDescriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> { $0.produzioneBatchId == batchId }
        )
        outputDescriptor.fetchLimit = 8
        let output = ((try? modelContext.fetch(outputDescriptor)) ?? [])
            .first { $0.isProductionBatchOutput }
        draft.traceabilityRecordId = output?.id

        var labelDescriptor = FetchDescriptor<ProductionLabelRecord>(
            predicate: #Predicate { $0.restaurantId == restaurantId }
        )
        let labels = (try? modelContext.fetch(labelDescriptor)) ?? []
        let lot = batch.batchCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = labels.first {
            ($0.lotCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(lot) == .orderedSame
        } ?? ProductionLabelLinkMatcher.existingLabel(for: draft, in: labels)

        Task {
            do {
                let label: ProductionLabelRecord
                if let existing {
                    label = existing
                } else {
                    label = try labelService.create(
                        draft: draft,
                        restaurantId: restaurantId,
                        user: user,
                        modelContext: modelContext
                    )
                }
                await ProductionLabelPrintQueue.shared.schedulePrint(
                    label: label,
                    restaurantName: restaurantName,
                    modelContext: modelContext,
                    countAsReprint: existing != nil
                )
                await MainActor.run {
                    isPrinting = false
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    isPrinting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startFreshSession() {
        completedBatch = nil
        selectedProduction = nil
        isPrinting = false
        sessionId = UUID()
        sessionItems = []
        camera.resetCaptureBuffer()
        camera.start()
    }
}
