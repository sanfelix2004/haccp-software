import SwiftUI
import SwiftData
import LabelScanningContract
import LabelScannerV2

/// Flusso tracciabilità: scatta → etichetta/alimento → produzione.
struct TraceabilityLotCaptureFlowView: View {
    let restaurantId: UUID
    let user: LocalUser
    var resumeSessionId: UUID? = nil
    /// `leavePending == true` mantiene la sessione riprendibile; `sessionId` è la sessione da tenere/chiudere.
    let onDismiss: (_ leavePending: Bool, _ sessionId: UUID?) -> Void
    let onUpdated: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query private var productTemplates: [ProductTemplate]
    @Query private var productions: [Production]
    @Query private var categories: [ProductionCategory]

    @StateObject private var camera = FinalizeReceiptCameraViewModel()

    @State private var sessionId = UUID()
    @State private var sessionItems: [LottoFoto] = []
    @State private var pendingCapture: PendingLottoCapture?
    @State private var lotDraftUserEdited = false
    @State private var selectedTemplate: ProductTemplate?
    @State private var supplierName = ""
    @State private var expiryDate = Date()
    @State private var expiryFromLabel = false
    @State private var expiryUserEdited = false
    @State private var suppressExpiryEditTracking = false
    @State private var showExpiredProductAlert = false
    @State private var pendingExpiredConfirm: PendingLottoCapture?
    @State private var showOptionalDetails = false
    @State private var foodSearchText = ""
    @State private var productionSearchText = ""
    @State private var presentedSheet: CaptureFlowSheet?
    @State private var showAddProductionInPicker = false
    @State private var productionShelfLifeDays = 3
    @State private var forcesCatalogDuration = false
    @State private var selectedProduction: Production?
    @State private var selectedProductionCategoryId: UUID?
    @State private var errorMessage: String?
    @State private var showExitWithoutProductionAlert = false
    @State private var selectedScanEngine: LabelScanEngineSelection = .current
    @State private var selectedReusedRecordIds: Set<UUID> = []

    private var sessionIngredientRecords: [TraceabilityRecord] {
        sessionItems.compactMap { lottoService.traceabilityRecord(for: $0, modelContext: modelContext) }
    }

    private func productionConstraint(for production: Production) -> ScadenzaCalculator.ProductionExpiryConstraint {
        ScadenzaCalculator.resolvedProductionExpiry(
            shelfLifeDays: productionShelfLifeDays,
            ingredientRecords: sessionIngredientRecords,
            ignoreIngredientConstraint: forcesCatalogDuration
        )
    }

    private let lottoService = LottoFotoService()
    private let libraryService = ProductionLibraryService()
    private let productionLibraryService = ProductionLibraryService()

    init(
        restaurantId: UUID,
        user: LocalUser,
        resumeSessionId: UUID? = nil,
        onDismiss: @escaping (_ leavePending: Bool, _ sessionId: UUID?) -> Void,
        onUpdated: @escaping () -> Void
    ) {
        self.restaurantId = restaurantId
        self.user = user
        self.resumeSessionId = resumeSessionId
        self.onDismiss = onDismiss
        self.onUpdated = onUpdated

        let rid = restaurantId
        _productTemplates = Query(
            filter: #Predicate<ProductTemplate> { $0.restaurantId == rid },
            sort: [SortDescriptor(\ProductTemplate.name)]
        )
        _productions = Query(
            filter: #Predicate<Production> { $0.restaurantId == rid },
            sort: [SortDescriptor(\Production.name)]
        )
        _categories = Query(
            filter: #Predicate<ProductionCategory> { $0.restaurantId == rid },
            sort: [SortDescriptor(\ProductionCategory.orderIndex)]
        )
    }

    private var currentStep: TraceabilityCaptureStep {
        if presentedSheet == .productionPicker { return .production }
        if pendingCapture != nil { return .label }
        return .shoot
    }

    private var isProductionPickerPresented: Bool {
        presentedSheet == .productionPicker
    }

    private var scopedTemplates: [ProductTemplate] {
        productTemplates
            .filter { $0.restaurantId == restaurantId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredFoodTemplates: [ProductTemplate] {
        let query = foodSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scopedTemplates }
        return scopedTemplates.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    private var sessionTemplateIds: [UUID] {
        sessionItems.compactMap(\.alimentoIngressoID)
    }

    private var scopedProductions: [Production] {
        productions
            .filter { $0.restaurantId == restaurantId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var scopedProductionCategories: [ProductionCategory] {
        categories
            .filter { $0.restaurantId == restaurantId }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var categoryFilteredProductions: [Production] {
        guard let selectedProductionCategoryId else { return scopedProductions }
        return scopedProductions.filter { $0.categoryId == selectedProductionCategoryId }
    }

    private var filteredProductions: [Production] {
        let query = productionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categoryFilteredProductions }
        return categoryFilteredProductions.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var lotMandatory: Bool {
        SettingsStorageService.shared.haccp.lotEntryMandatory
    }

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            if pendingCapture == nil && !isProductionPickerPresented {
                FullScreenLotCameraView(
                    camera: camera,
                    isProcessing: false,
                    sessionPhotoCount: sessionItems.count,
                    onCapture: { camera.capturePhoto() }
                )
                .ignoresSafeArea()
            }

            VStack {
                captureHeader
                if pendingCapture == nil && !isProductionPickerPresented {
                    enginePicker
                        .padding(.top, 8)
                }
                Spacer()
                    .allowsHitTesting(false)
                if pendingCapture == nil, !sessionItems.isEmpty, !isProductionPickerPresented {
                    TraceabilitySessionDock(items: sessionItems, onFinish: presentProductionPicker)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 100)
                } else if pendingCapture == nil, sessionItems.isEmpty, !isProductionPickerPresented {
                    // Accesso rapido al magazzino (senza scattare foto)
                    Button(action: presentProductionPickerFromWarehouse) {
                        Label("Usa solo dal magazzino", systemImage: "archivebox.fill")
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.5), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 110)
                }
            }

            if let pending = pendingCapture {
                captureReviewOverlay(pending)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: beginCaptureSession)
        .onDisappear { camera.stop() }
        .onReceive(camera.$capturedPhotoData) { data in
            guard let data, !data.isEmpty, pendingCapture == nil else { return }
            handleCapturedPhoto(data)
        }
        .sheet(item: $presentedSheet, onDismiss: handleSheetDismissed) { sheet in
            switch sheet {
            case .addIncomingFood:
                TraceabilityQuickAddIncomingFoodSheet(
                    restaurantId: restaurantId,
                    existingTemplates: scopedTemplates,
                    suggestedName: foodSearchText,
                    onSaved: { template in
                        presentedSheet = nil
                        selectTemplate(template)
                        foodSearchText = ""
                    },
                    onCancel: { presentedSheet = nil },
                    onError: { message in
                        presentedSheet = nil
                        errorMessage = message
                    }
                )
            case .productionPicker:
                productionPickerSheet
            }
        }
        .alert("Tracciabilità", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Uscire dalla tracciabilità?", isPresented: $showExitWithoutProductionAlert) {
            Button("Lascia in sospeso") {
                exitCapture(leavePending: true)
            }
            Button("Chiudi sessione", role: .destructive) {
                exitCapture(leavePending: false)
            }
            Button("Resta qui", role: .cancel) {
                if pendingCapture == nil, !isProductionPickerPresented {
                    camera.resetCaptureBuffer()
                    camera.start()
                }
            }
        } message: {
            Text("Hai \(sessionItems.count) foto non ancora collegate a un piatto. Puoi lasciarle in sospeso e riprendere dopo, oppure chiudere la sessione.")
        }
        .alert("Prodotto scaduto", isPresented: $showExpiredProductAlert) {
            Button("Annulla", role: .cancel) {
                pendingExpiredConfirm = nil
            }
            Button("Accetto comunque", role: .destructive) {
                if let pending = pendingExpiredConfirm {
                    performConfirm(pending, acceptedDespiteExpired: true)
                }
                pendingExpiredConfirm = nil
            }
        } message: {
            Text("ATTENZIONE: La data di scadenza letta indica che il prodotto è già SCADUTO. Verificare l'etichetta.")
        }
    }

    // MARK: - Header

    private var captureHeader: some View {
        HStack(spacing: 12) {
            Button(action: attemptClose) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            TraceabilityCaptureStepBar(current: currentStep, sessionCount: sessionItems.count)

            if sessionItems.isEmpty {
                Color.clear.frame(width: 36, height: 36)
            } else if pendingCapture == nil && !isProductionPickerPresented {
                Button(action: presentProductionPicker) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(theme.colorPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ho finito le foto")
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 52)
    }

    private var enginePicker: some View {
        Picker("Motore OCR", selection: $selectedScanEngine) {
            ForEach(LabelScanEngineSelection.allCases) { engine in
                Text(engine.title).tag(engine)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 160)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
        .onChange(of: selectedScanEngine) { _, newValue in
            LabelScanEngineSelection.current = newValue
        }
        .accessibilityLabel("Motore scansione etichetta V1 o V2")
    }

    // MARK: - Revisione scatto

    private func captureReviewOverlay(_ pending: PendingLottoCapture) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.4).ignoresSafeArea()

                VStack(spacing: 0) {
                    reviewHeader

                    ScrollView {
                        if isWideLayout {
                            HStack(alignment: .top, spacing: 20) {
                                reviewPhotoColumn(pending)
                                    .frame(maxWidth: 280)
                                reviewFormColumn(pending)
                            }
                            .padding(20)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                reviewPhotoColumn(pending)
                                reviewFormColumn(pending)
                            }
                            .padding(20)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)

                    reviewActionBar(pending)
                }
                .frame(maxHeight: isWideLayout ? geometry.size.height * 0.92 : geometry.size.height * 0.88)
                .background(theme.colorBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, y: -6)
                .padding(.horizontal, isWideLayout ? 24 : 0)
                .padding(.bottom, isWideLayout ? 24 : 0)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var reviewHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Etichetta \(sessionItems.count + 1)")
                    .font(theme.typography.headline)
                Text("Lotto e alimento in ingresso")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer()
            Button("Annulla") { discardPending() }
                .font(theme.typography.subheadline.weight(.semibold))
                .foregroundStyle(theme.colorError)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.colorSurface)
    }

    private func reviewPhotoColumn(_ pending: PendingLottoCapture) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = HACCPZoomablePhotoPreview(
                data: pending.photoData,
                height: isWideLayout ? 200 : 140,
                zoomTitle: "Anteprima etichetta"
            ) {
                preview
            }

            lotStatusBanner(pending)
            expiredProductBanner
            lotField(pending)
            expiryField(pending)
        }
    }

    private func reviewFormColumn(_ pending: PendingLottoCapture) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sessionFoodChips

            HStack {
                TraceabilityInlineSearchField(
                    placeholder: "Cerca alimento…",
                    text: $foodSearchText
                )
                Button {
                    presentAddIncomingFood()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.colorPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aggiungi alimento")
            }

            if filteredFoodTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nessun alimento trovato.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    Button("Aggiungi «\(foodSearchText)» al catalogo") {
                        presentAddIncomingFood()
                    }
                    .font(theme.typography.caption.weight(.semibold))
                }
            } else {
                ProductSelectionGridView(
                    products: filteredFoodTemplates,
                    recentProductIds: sessionTemplateIds,
                    selectedProductId: selectedTemplate?.id,
                    onSelect: selectTemplate
                )
            }

            if selectedTemplate != nil {
                optionalDetailsSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sessionFoodChips: some View {
        Group {
            if !sessionItems.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 88), spacing: 6)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(sessionItems, id: \.id) { item in
                        if let name = item.alimentoIngressoNameSnapshot {
                            Text(name)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(theme.colorSuccess.opacity(0.12))
                                .foregroundStyle(theme.colorSuccess)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lotStatusBanner(_ pending: PendingLottoCapture) -> some View {
        if pending.isLotExtracting {
            HStack(spacing: 8) {
                ProgressView()
                Text(pending.testoLottoOCR != nil || pending.labelExpiryDate != nil
                     ? "Affinamento lettura…"
                     : "Lettura lotto in corso…")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if let error = pending.lotExtractionError {
            Label(error, systemImage: "info.circle.fill")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorWarning)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colorWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if let lot = pending.testoLottoOCR, !lot.isEmpty {
            let uncertain = (pending.ocrConfidence ?? 1) < GroqLotExtractor.manualVerificationThreshold
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lot)
                        .font(theme.typography.caption.weight(.semibold).monospaced())
                    if uncertain {
                        Text("Verifica sull'etichetta — lettura AI incerta")
                            .font(theme.typography.caption2)
                    }
                }
            } icon: {
                Image(systemName: uncertain ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            }
            .font(theme.typography.caption)
            .foregroundStyle(uncertain ? theme.colorWarning : theme.colorSuccess)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((uncertain ? theme.colorWarning : theme.colorSuccess).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private var expiredProductBanner: some View {
        if isExpiryReadAsExpired {
            VStack(alignment: .leading, spacing: 6) {
                Label("PRODOTTO SCADUTO", systemImage: "exclamationmark.octagon.fill")
                    .font(theme.typography.caption.weight(.bold))
                    .foregroundStyle(theme.colorError)
                Text("La scadenza letta è antecedente a oggi. Verifica l'etichetta prima di confermare.")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorError.opacity(0.9))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colorError.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.colorError.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var isExpiryReadAsExpired: Bool {
        ProductExpiryEvaluator.isExpiredByDate(expiryDate)
            && (expiryFromLabel || pendingCapture?.expiryFromLabel == true)
            && !expiryUserEdited
    }

    private func lotField(_ pending: PendingLottoCapture) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Codice lotto")
                    .font(theme.typography.caption.weight(.semibold))
                Spacer()
                Text(lotMandatory ? "Obbligatorio" : "Opzionale")
                    .font(.caption2)
                    .foregroundStyle(lotMandatory ? theme.colorError : theme.colorTextSecondary)
            }
            TextField("Es. L26160", text: bindingLotDraft(for: pending))
                .font(theme.typography.title3.weight(.semibold).monospaced())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(theme.colorSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func expiryField(_ pending: PendingLottoCapture) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Scadenza")
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colorTextSecondary)
                Spacer()
                if pending.isLotExtracting {
                    Text("Lettura in corso…")
                        .font(.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                } else if expiryFromLabel && !expiryUserEdited {
                    let uncertain = (pending.ocrConfidence ?? 1) < GroqLotExtractor.manualVerificationThreshold
                    Label(
                        uncertain ? "Letta dall'etichetta — da verificare" : "Letta dall'etichetta",
                        systemImage: uncertain ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(uncertain ? theme.colorWarning : theme.colorSuccess)
                } else if expiryUserEdited {
                    Text("Impostata manualmente")
                        .font(.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }

            DatePicker(
                "Scadenza",
                selection: $expiryDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.colorSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: expiryDate) { _, _ in
                guard !suppressExpiryEditTracking else { return }
                expiryUserEdited = true
                expiryFromLabel = false
            }
        }
    }

    private var optionalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showOptionalDetails.toggle()
                }
            } label: {
                HStack {
                    Label("Fornitore (opzionale)", systemImage: "building.2")
                        .font(theme.typography.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: showOptionalDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(theme.colorTextSecondary)
            }
            .buttonStyle(.plain)

            if showOptionalDetails {
                TextField("Nome fornitore", text: $supplierName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(theme.colorSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .background(theme.colorSurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func reviewActionBar(_ pending: PendingLottoCapture) -> some View {
        let canConfirm = selectedTemplate != nil
            && (!lotMandatory || !pending.lotDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        return HStack(spacing: 12) {
            Button("Scarta") { discardPending() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

            Button {
                confirmPending(pending)
            } label: {
                Text(sessionItems.isEmpty ? "Conferma e continua" : "Conferma · scatta ancora")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canConfirm)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.colorSurface)
    }

    private func bindingLotDraft(for pending: PendingLottoCapture) -> Binding<String> {
        Binding(
            get: { pendingCapture?.lotDraft ?? pending.lotDraft },
            set: { newValue in
                guard var current = pendingCapture else { return }
                lotDraftUserEdited = true
                current.lotDraft = newValue
                pendingCapture = current
            }
        )
    }

    // MARK: - Produzione

    private var productionPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TraceabilitySessionSummaryStrip(items: sessionItems)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("A quale piatto colleghi questa produzione?")
                            .font(theme.typography.headline)
                        Text("Tutte le etichette della sessione verranno raggruppate sotto il piatto scelto.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }

                    // Pannello riutilizzo alimenti già in magazzino
                    TraceabilityIngredientReusePanel(
                        restaurantId: restaurantId,
                        sessionLottoIds: Set(sessionItems.map(\.id)),
                        selectedRecordIds: $selectedReusedRecordIds
                    )

                    Divider()

                    TraceabilityInlineSearchField(
                        placeholder: "Cerca piatto…",
                        text: $productionSearchText
                    )

                    HStack {
                        Spacer()
                        Button {
                            showAddProductionInPicker = true
                        } label: {
                            Label("Aggiungi piatto", systemImage: "plus.circle.fill")
                                .font(theme.typography.caption.weight(.semibold))
                        }
                    }

                    productionCategoryTabs

                    if filteredProductions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nessun piatto trovato.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                            if !productionSearchText.isEmpty {
                                Button("Aggiungi «\(productionSearchText)» al catalogo") {
                                    showAddProductionInPicker = true
                                }
                                .font(theme.typography.caption.weight(.semibold))
                            }
                        }
                    } else {
                        BlastChillingProductionGridView(
                            productions: filteredProductions,
                            selectedProductionId: selectedProduction?.id,
                            showsShelfLife: true,
                            onSelect: {
                                selectedProduction = $0
                                productionShelfLifeDays = $0.defaultShelfLifeDays
                                forcesCatalogDuration = false
                            }
                        )
                    }
                }
                .padding()
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Scegli piatto")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Altre foto") { presentedSheet = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva tracciabilità") {
                        if let production = selectedProduction {
                            associateProduction(production)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedProduction == nil && selectedReusedRecordIds.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let production = selectedProduction {
                    let constraint = productionConstraint(for: production)
                    let totalCount = sessionItems.count + selectedReusedRecordIds.count
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "fork.knife")
                            Text(production.name)
                                .font(theme.typography.subheadline.weight(.semibold))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(totalCount) alimenti totali")
                                    .font(theme.typography.caption.weight(.semibold))
                                    .foregroundStyle(theme.colorTextPrimary)
                                if !selectedReusedRecordIds.isEmpty {
                                    Text("\(sessionItems.count) nuovi · \(selectedReusedRecordIds.count) dal magazzino")
                                        .font(theme.typography.caption2)
                                        .foregroundStyle(theme.colorTextSecondary)
                                }
                            }
                        }

                        HStack {
                            Text("Scadenza: \(constraint.suggestedExpiryDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(theme.typography.caption.weight(.semibold))
                                .foregroundStyle(theme.colorPrimary)
                            Spacer()
                            if productionShelfLifeDays != production.defaultShelfLifeDays {
                                Text("Catalogo \(production.defaultShelfLifeDays) gg")
                                    .font(theme.typography.caption2)
                                    .foregroundStyle(theme.colorTextSecondary)
                            }
                        }

                        if let ingredient = constraint.limitingIngredientName,
                           !forcesCatalogDuration,
                           constraint.isIngredientLimited {
                            Text("Vincolo ingrediente: \(ingredient) scade prima — la produzione non può durare di più.")
                                .font(theme.typography.caption2)
                                .foregroundStyle(theme.colorWarning)
                            Toggle("Forza durata catalogo (cottura)", isOn: $forcesCatalogDuration)
                                .font(theme.typography.caption)
                        }

                        ShelfLifeDaysNumberField(days: $productionShelfLifeDays, label: "Durata piatto")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationDestination(isPresented: $showAddProductionInPicker) {
                TraceabilityQuickAddProductionSheet(
                    restaurantId: restaurantId,
                    categories: scopedProductionCategories,
                    existingProductions: scopedProductions,
                    suggestedName: productionSearchText,
                    onSaved: { production in
                        showAddProductionInPicker = false
                        selectedProduction = production
                        productionShelfLifeDays = production.defaultShelfLifeDays
                    },
                    onCancel: { showAddProductionInPicker = false },
                    onError: { message in
                        showAddProductionInPicker = false
                        errorMessage = message
                    }
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
            ForEach(scopedProductionCategories) { category in
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

    // MARK: - Azioni

    private func beginCaptureSession() {
        if let resumeSessionId {
            sessionId = resumeSessionId
        }
        reloadSession()
        camera.resetCaptureBuffer()
        camera.start()
        GroqApiKeyService.prefetchVisionModels()
        Task { await prepareCatalogIfNeeded() }
    }

    @MainActor
    private func prepareCatalogIfNeeded() async {
        await Task.yield()
        ProductTemplateSeeder.ensureTemplates(restaurantId: restaurantId, modelContext: modelContext)
        libraryService.ensureDefaults(
            restaurantId: restaurantId,
            modelContext: modelContext
        )
        reloadSession()
    }

    private func reloadSession() {
        modelContext.processPendingChanges()
        sessionItems = lottoService.sessionItems(sessionId: sessionId, modelContext: modelContext)
    }

    @MainActor
    private func handleCapturedPhoto(_ data: Data) {
        let pending = lottoService.makePendingCapture(photoData: data)
        let captureId = pending.id
        pendingCapture = pending
        lotDraftUserEdited = false
        selectedTemplate = nil
        foodSearchText = ""
        showOptionalDetails = !supplierName.isEmpty
        expiryFromLabel = false
        expiryUserEdited = false
        camera.resetCaptureBuffer()

        Task {
            await extractLotInBackground(captureId: captureId, photoData: data)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if pendingCapture != nil {
                camera.stop()
            }
        }
    }

    @MainActor
    private func applyLotOutcome(_ outcome: ProductionLotCaptureOutcome, to captureId: UUID, isFinal: Bool) {
        guard var current = pendingCapture, current.id == captureId else { return }

        let sanitizedLot = outcome.lotCode.flatMap {
            LabelLotSanitizer.validateLot($0, rawContext: outcome.rawText)
        }
        if !lotDraftUserEdited,
           let lot = sanitizedLot?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lot.isEmpty {
            current.lotDraft = lot
        }
        current.testoLottoOCR = sanitizedLot
        let raw = outcome.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        current.ocrRawText = raw.isEmpty ? nil : raw
        current.ocrConfidence = outcome.confidence

        if isFinal {
            current.isLotExtracting = false
            current.lotExtractionError = outcome.analysisNote
                ?? (outcome.confidence < GroqLotExtractor.manualVerificationThreshold
                    ? "Verifica lotto e scadenza sull'etichetta — lettura AI incerta."
                    : nil)
        }

        if let labelExpiry = outcome.expiryDate {
            let year = Calendar.current.component(.year, from: labelExpiry)
            let currentYear = Calendar.current.component(.year, from: Date())
            // Rete di sicurezza UI: mai bindare allucinazioni 2031+ sul DatePicker.
            if year > currentYear + 3 || year < currentYear - 1 {
                // Ignora — lascia scadenza manuale / valore precedente non allucinato.
            } else {
                current.labelExpiryDate = labelExpiry
                current.expiryFromLabel = true
                suppressExpiryEditTracking = true
                expiryDate = labelExpiry
                suppressExpiryEditTracking = false
                expiryFromLabel = true
                expiryUserEdited = false
            }
        }

        pendingCapture = current

        if isFinal, outcome.lotCode?.isEmpty == false, !lotDraftUserEdited {
            HapticManager.shared.notification(.success)
        } else if isFinal, outcome.expiryDate != nil {
            HapticManager.shared.notification(.success)
        }
    }

    /// OCR/AI su thread di background; aggiornamenti UI sul MainActor (niente freeze).
    @MainActor
    private func extractLotInBackground(captureId: UUID, photoData: Data) async {
        if selectedScanEngine == .v2 {
            await extractLotWithSelectedEngine(captureId: captureId, photoData: photoData)
            return
        }

        let service = LottoFotoService()
        var previewOutcome: ProductionLotCaptureOutcome?

        let preview = await Task.detached(priority: .userInitiated) {
            await service.extractLotLocalPreview(from: photoData)
        }.value

        if let preview {
            previewOutcome = preview
            applyLotOutcome(preview, to: captureId, isFinal: false)
            if preview.lotCode != nil, preview.expiryDate != nil {
                applyLotOutcome(preview, to: captureId, isFinal: true)
                return
            }
        }

        if GroqApiKeyService.hasAnyKey() {
            do {
                let enhanced = try await Task.detached(priority: .userInitiated) {
                    try await service.extractLotGroqOnly(from: photoData)
                }.value
                let merged = mergeLotOutcomes(preview: previewOutcome, enhanced: enhanced)
                applyLotOutcome(merged, to: captureId, isFinal: true)
                return
            } catch {
                if let previewOutcome {
                    applyLotOutcome(previewOutcome, to: captureId, isFinal: true)
                    return
                }
                guard var current = pendingCapture, current.id == captureId else { return }
                current.isLotExtracting = false
                current.lotExtractionError = friendlyLotExtractionError(error)
                pendingCapture = current
                return
            }
        }

        if let previewOutcome {
            applyLotOutcome(previewOutcome, to: captureId, isFinal: true)
            return
        }

        do {
            let outcome = try await Task.detached(priority: .userInitiated) {
                try await service.extractLot(from: photoData)
            }.value
            applyLotOutcome(outcome, to: captureId, isFinal: true)
        } catch {
            guard var current = pendingCapture, current.id == captureId else { return }
            current.isLotExtracting = false
            current.lotExtractionError = friendlyLotExtractionError(error)
            pendingCapture = current
        }
    }

    @MainActor
    private func extractLotWithSelectedEngine(captureId: UUID, photoData: Data) async {
        let engine = LabelScanningEngineFactory.make(selection: selectedScanEngine)
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try await engine.scan(imageData: photoData)
            }.value
            applyLotOutcome(LabelScanResultBridge.toCaptureOutcome(result), to: captureId, isFinal: true)
        } catch {
            guard var current = pendingCapture, current.id == captureId else { return }
            current.isLotExtracting = false
            current.lotExtractionError = friendlyLotExtractionError(error)
            pendingCapture = current
        }
    }

    private func mergeLotOutcomes(
        preview: ProductionLotCaptureOutcome?,
        enhanced: ProductionLotCaptureOutcome
    ) -> ProductionLotCaptureOutcome {
        guard let preview else { return enhanced }

        // Groq vince sul lotto solo se valido; scarta etichette tipo "number"/"LATTY".
        let mergedLot: String? = {
            let context = [preview.rawText, enhanced.rawText].joined(separator: "\n")
            let groq = enhanced.lotCode.flatMap {
                LabelLotSanitizer.validateLot($0, rawContext: context)
            }
            if let groq, !groq.isEmpty { return groq }
            return preview.lotCode.flatMap {
                LabelLotSanitizer.validateLot($0, rawContext: context)
            }
        }()

        // Scadenza: mai far vincere un'allucinazione Groq (nil o anno folle) sulla data Apple Vision.
        let mergedExpiry = preferredMergedExpiry(
            preview: preview.expiryDate,
            enhanced: enhanced.expiryDate
        )

        return ProductionLotCaptureOutcome(
            rawText: [preview.rawText, enhanced.rawText].filter { !$0.isEmpty }.joined(separator: "\n"),
            lotCode: mergedLot,
            ingredientName: enhanced.ingredientName ?? preview.ingredientName,
            expiryDate: mergedExpiry,
            confidence: max(preview.confidence, enhanced.confidence),
            lotParseAudit: preview.lotParseAudit + enhanced.lotParseAudit + [
                mergedExpiryAudit(preview: preview.expiryDate, enhanced: enhanced.expiryDate, chosen: mergedExpiry)
            ].compactMap { $0 },
            analysisNote: enhanced.analysisNote ?? preview.analysisNote
        )
    }

    /// Se Groq non ha scadenza (scartata dal guardrail) o ha un anno folle, prevale Apple Vision.
    private func preferredMergedExpiry(preview: Date?, enhanced: Date?) -> Date? {
        guard let enhanced else { return preview }
        guard let preview else { return enhanced }

        let currentYear = Calendar.current.component(.year, from: Date())
        let enhancedYear = Calendar.current.component(.year, from: enhanced)
        if enhancedYear > currentYear + 3 || enhancedYear < currentYear - 1 {
            return preview
        }
        // Entrambi plausibili: preferisci Groq (visione multi-crop) ma non azzerare il locale.
        return enhanced
    }

    private func mergedExpiryAudit(preview: Date?, enhanced: Date?, chosen: Date?) -> String? {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        df.locale = Locale(identifier: "it_IT")
        func fmt(_ d: Date?) -> String { d.map { df.string(from: $0) } ?? "nil" }
        if enhanced == nil, preview != nil, chosen == preview {
            return "Merge scadenza: Groq nil → preservata anteprima locale \(fmt(preview))"
        }
        if let enhanced, let preview, chosen == preview, enhanced != preview {
            return "Merge scadenza: scartata allucinazione Groq \(fmt(enhanced)) → locale \(fmt(preview))"
        }
        return nil
    }

    private func selectTemplate(_ template: ProductTemplate) {
        selectedTemplate = template
        if supplierName.isEmpty {
            supplierName = TraceabilitySupplierMemory.lastUsed(for: restaurantId) ?? ""
            showOptionalDetails = !supplierName.isEmpty
        }
        HapticManager.shared.selection()
    }

    private func discardPending(resumeCamera: Bool = true) {
        pendingCapture = nil
        lotDraftUserEdited = false
        selectedTemplate = nil
        foodSearchText = ""
        expiryFromLabel = false
        expiryUserEdited = false
        camera.resetCaptureBuffer()
        if resumeCamera {
            camera.start()
        }
    }

    private func confirmPending(_ pending: PendingLottoCapture) {
        guard selectedTemplate != nil else {
            errorMessage = "Seleziona un alimento in ingresso."
            return
        }
        if (expiryUserEdited || expiryFromLabel),
           ProductExpiryEvaluator.isExpiredByDate(expiryDate) {
            pendingExpiredConfirm = pending
            showExpiredProductAlert = true
            return
        }
        performConfirm(pending, acceptedDespiteExpired: false)
    }

    private func performConfirm(_ pending: PendingLottoCapture, acceptedDespiteExpired: Bool) {
        guard let template = selectedTemplate else {
            errorMessage = "Seleziona un alimento in ingresso."
            return
        }
        do {
            var captureToConfirm = pending
            if expiryUserEdited || expiryFromLabel {
                captureToConfirm.labelExpiryDate = expiryDate
                captureToConfirm.expiryFromLabel = expiryFromLabel && !expiryUserEdited
            }
            let lotto = try lottoService.confirmCapture(
                pending: captureToConfirm,
                template: template,
                supplier: supplierName,
                expiryDate: expiryUserEdited || expiryFromLabel ? expiryDate : nil,
                expiryFromLabel: expiryFromLabel && !expiryUserEdited,
                expiryUserEdited: expiryUserEdited,
                acceptedDespiteExpired: acceptedDespiteExpired,
                sessionId: sessionId,
                user: user,
                modelContext: modelContext
            )
            TraceabilitySupplierMemory.remember(supplierName, restaurantId: restaurantId)
            pendingCapture = nil
            selectedTemplate = nil
            foodSearchText = ""
            expiryFromLabel = false
            expiryUserEdited = false
            reloadSession()
            onUpdated()
            camera.resetCaptureBuffer()
            camera.start()
            HapticManager.shared.notification(.success)
        } catch let error as ExpiryTrackingError {
            pendingExpiredConfirm = pending
            showExpiredProductAlert = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func attemptClose() {
        if pendingCapture != nil {
            discardPending(resumeCamera: false)
        }
        if sessionItems.isEmpty {
            exitCapture(leavePending: false)
        } else {
            showExitWithoutProductionAlert = true
        }
    }

    private func exitCapture(leavePending: Bool) {
        camera.stop()
        pendingCapture = nil
        presentedSheet = nil
        let sid: UUID? = sessionItems.isEmpty ? nil : sessionId
        onDismiss(leavePending, sid)
    }

    private func presentAddIncomingFood() {
        guard presentedSheet == nil else { return }
        camera.stop()
        presentedSheet = .addIncomingFood
    }

    private func handleSheetDismissed() {
        showAddProductionInPicker = false
        if pendingCapture == nil, !sessionItems.isEmpty, presentedSheet == nil {
            resumeCameraAfterProductionPicker()
        } else if pendingCapture == nil, sessionItems.isEmpty, presentedSheet == nil {
            camera.resetCaptureBuffer()
            camera.start()
        }
    }

    private func presentProductionPicker() {
        guard pendingCapture == nil, !sessionItems.isEmpty, presentedSheet == nil else { return }
        selectedProduction = nil
        selectedProductionCategoryId = nil
        productionSearchText = ""
        forcesCatalogDuration = false
        showAddProductionInPicker = false
        selectedReusedRecordIds = []
        camera.stop()
        presentedSheet = .productionPicker
    }

    /// Apre il picker anche senza aver scattato foto (solo per riutilizzo dal magazzino)
    private func presentProductionPickerFromWarehouse() {
        guard pendingCapture == nil, presentedSheet == nil else { return }
        selectedProduction = nil
        selectedProductionCategoryId = nil
        productionSearchText = ""
        forcesCatalogDuration = false
        showAddProductionInPicker = false
        selectedReusedRecordIds = []
        camera.stop()
        presentedSheet = .productionPicker
    }

    private func resumeCameraAfterProductionPicker() {
        guard !sessionItems.isEmpty else { return }
        camera.resetCaptureBuffer()
        camera.start()
    }

    private func associateProduction(_ production: Production) {
        do {
            // Raccogli i record riutilizzati dal database
            var reusedRecords: [TraceabilityRecord] = []
            if !selectedReusedRecordIds.isEmpty {
                for recordId in selectedReusedRecordIds {
                    var descriptor = FetchDescriptor<TraceabilityRecord>(
                        predicate: #Predicate<TraceabilityRecord> { $0.id == recordId }
                    )
                    descriptor.fetchLimit = 1
                    if let record = (try? modelContext.fetch(descriptor))?.first {
                        reusedRecords.append(record)
                    }
                }
            }

            // Chiama l'associazione unificata nel service (gestisce sia nuovi scatti che riutilizzati)
            try lottoService.associateWithProductions(
                lottoFotos: sessionItems,
                reusedRecords: reusedRecords,
                productions: [production],
                user: user,
                modelContext: modelContext,
                productionShelfLifeDays: productionShelfLifeDays != production.defaultShelfLifeDays
                    ? productionShelfLifeDays
                    : nil,
                ignoreIngredientConstraint: forcesCatalogDuration
            )

            presentedSheet = nil
            selectedProduction = nil
            selectedProductionCategoryId = nil
            selectedReusedRecordIds = []
            sessionId = UUID()
            sessionItems = []
            supplierName = ""
            onUpdated()
            HapticManager.shared.notification(.success)
            exitCapture(leavePending: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private func friendlyLotExtractionError(_ error: Error) -> String {
    if let groq = error as? GroqLotError {
        return "Lettura automatica non riuscita. \(groq.localizedDescription)"
    }
    let message = error.localizedDescription
    if message.localizedCaseInsensitiveContains("model_not_found")
        || message.localizedCaseInsensitiveContains("maverick")
        || message.localizedCaseInsensitiveContains("does not exist") {
        return "Servizio AI etichette non disponibile. Ricompila l'app aggiornata oppure inserisci lotto e scadenza manualmente."
    }
    if message.count > 120 {
        return "Lettura automatica non riuscita. Inserisci lotto e scadenza manualmente."
    }
    return "Lettura automatica non riuscita. \(message)"
}

// MARK: - Sheet unico (evita conflitti SwiftUI)

private enum CaptureFlowSheet: Identifiable {
    case addIncomingFood
    case productionPicker

    var id: String {
        switch self {
        case .addIncomingFood: "addIncomingFood"
        case .productionPicker: "productionPicker"
        }
    }
}
