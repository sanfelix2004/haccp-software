import SwiftUI
import SwiftData
import UIKit

/// Flusso: foto fattura/DDT → tabella → scegli alimenti → foto per ciascuno → associa piatto.
struct TraceabilityInvoiceCaptureFlowView: View {
    let restaurantId: UUID
    let user: LocalUser
    let onDismiss: () -> Void
    let onUpdated: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @Query private var productTemplates: [ProductTemplate]
    @Query private var productions: [Production]
    @Query private var categories: [ProductionCategory]

    @StateObject private var camera = FinalizeReceiptCameraViewModel()

    @State private var phase: Phase = .shootDocument
    @State private var documentPhotoData: Data?
    @State private var extraction: InvoiceDocumentExtraction?
    @State private var selectedLineIds: Set<UUID> = []
    @State private var selectedQueue: [InvoiceSelectedLine] = []
    @State private var queueIndex = 0
    @State private var pendingCapture: PendingLottoCapture?
    @State private var selectedTemplate: ProductTemplate?
    @State private var lotDraft = ""
    @State private var supplierName = ""
    @State private var foodSearchText = ""
    @State private var showOptionalExpiry = false
    @State private var expiryDate = Date()
    @State private var expiryEnabled = false
    @State private var sessionId = UUID()
    @State private var sessionItems: [LottoFoto] = []
    @State private var sessionRecords: [TraceabilityRecord] = []
    @State private var showAssociateSheet = false
    @State private var showAddIncomingFood = false
    @State private var errorMessage: String?
    @State private var isExtracting = false
    @State private var rowSearchText = ""
    @State private var editingRow: InvoiceLineItem?
    @State private var editCode = ""
    @State private var editLot = ""
    @State private var editDescription = ""

    private let extractor = InvoiceDocumentExtractor()
    private let lottoService = LottoFotoService()

    private enum Phase: Equatable {
        case shootDocument
        case selectRows
        case shootItem
        case reviewItem
    }

    init(
        restaurantId: UUID,
        user: LocalUser,
        onDismiss: @escaping () -> Void,
        onUpdated: @escaping () -> Void
    ) {
        self.restaurantId = restaurantId
        self.user = user
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

    private var scopedTemplates: [ProductTemplate] {
        productTemplates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredTemplates: [ProductTemplate] {
        let q = foodSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return scopedTemplates }
        return scopedTemplates.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.category.rawValue.localizedCaseInsensitiveContains(q)
        }
    }

    private var filteredRows: [InvoiceLineItem] {
        guard let extraction else { return [] }
        let q = rowSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return extraction.rows }
        return extraction.rows.filter {
            $0.description.lowercased().contains(q)
                || ($0.lotCode?.lowercased().contains(q) ?? false)
                || ($0.productCode?.lowercased().contains(q) ?? false)
        }
    }

    private var currentQueueItem: InvoiceSelectedLine? {
        guard selectedQueue.indices.contains(queueIndex) else { return nil }
        return selectedQueue[queueIndex]
    }

    var body: some View {
        ZStack {
            switch phase {
            case .shootDocument:
                documentCameraLayer
            case .selectRows:
                rowPickerLayer
            case .shootItem:
                itemCameraLayer
            case .reviewItem:
                if let pending = pendingCapture {
                    itemReviewLayer(pending)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            GroqApiKeyService.prefetchVisionModels()
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onReceive(camera.$capturedPhotoData) { data in
            guard let data, !data.isEmpty else { return }
            switch phase {
            case .shootDocument where !isExtracting:
                handleDocumentPhoto(data)
            case .shootItem where pendingCapture == nil:
                handleItemPhoto(data)
            default:
                break
            }
        }
        .sheet(isPresented: $showAssociateSheet) {
            associateSheet
        }
        .sheet(isPresented: $showAddIncomingFood) {
            TraceabilityQuickAddIncomingFoodSheet(
                restaurantId: restaurantId,
                existingTemplates: scopedTemplates,
                suggestedName: foodSearchText.isEmpty
                    ? (currentQueueItem?.line.description ?? "")
                    : foodSearchText,
                onSaved: { template in
                    showAddIncomingFood = false
                    selectedTemplate = template
                    foodSearchText = ""
                },
                onCancel: { showAddIncomingFood = false },
                onError: { message in
                    showAddIncomingFood = false
                    errorMessage = message
                }
            )
        }
        .alert("Fattura / DDT", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Document camera

    private var documentCameraLayer: some View {
        ZStack {
            FullScreenLotCameraView(
                camera: camera,
                isProcessing: isExtracting,
                sessionPhotoCount: 0,
                onCapture: { camera.capturePhoto() }
            )
            .ignoresSafeArea()

            VStack {
                headerBar(
                    title: "Foto fattura / DDT",
                    subtitle: "Inquadra l’intera tabella prodotti"
                )
                Spacer()
                if isExtracting {
                    ProgressView("Lettura documento…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(.bottom, 120)
                } else {
                    Text("L’app riconosce fattura o documento di trasporto e trascrive la tabella.")
                        .font(theme.typography.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 110)
                }
            }
        }
    }

    // MARK: - Row picker

    private var rowPickerLayer: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let extraction {
                        documentBanner(extraction)
                    }

                    TraceabilityInlineSearchField(
                        placeholder: "Cerca prodotto, lotto o codice…",
                        text: $rowSearchText
                    )

                    Text("Seleziona gli alimenti. Tocca la matita per correggere Codice, Lotto o Descrizione se l’OCR ha sbagliato. Per ciascuno scatterai una foto — scadenza non obbligatoria.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)

                    if filteredRows.isEmpty {
                        Text("Nessuna riga trovata. Riprova con una foto più nitida.")
                            .font(theme.typography.subheadline)
                            .foregroundStyle(theme.colorTextSecondary)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(filteredRows) { row in
                            rowCard(row)
                        }
                    }
                }
                .padding()
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Scegli dalla fattura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { closeFlow() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Altra foto") { resetToDocumentCamera() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Avanti (\(selectedLineIds.count))") {
                        beginItemCaptureQueue()
                    }
                    .disabled(selectedLineIds.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedLineIds.isEmpty {
                    Text("\(selectedLineIds.count) selezionati · foto obbligatoria per ciascuno · scadenza opzionale")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .sheet(item: $editingRow) { row in
                invoiceRowEditorSheet(row)
            }
        }
    }

    private func documentBanner(_ extraction: InvoiceDocumentExtraction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(extraction.documentKind.label, systemImage: "doc.text.viewfinder")
                .font(theme.typography.subheadline.weight(.semibold))
                .foregroundStyle(theme.colorPrimary)
            HStack(spacing: 12) {
                if let supplier = extraction.supplierName, !supplier.isEmpty {
                    Text(supplier)
                        .font(theme.typography.caption)
                }
                if let number = extraction.documentNumber {
                    Text("N. \(number)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            Text("\(extraction.rows.count) prodotti trascritti")
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rowCard(_ row: InvoiceLineItem) -> some View {
        let isOn = selectedLineIds.contains(row.id)
        return HStack(alignment: .top, spacing: 10) {
            Button {
                if isOn {
                    selectedLineIds.remove(row.id)
                } else {
                    selectedLineIds.insert(row.id)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isOn ? theme.colorPrimary : theme.colorDivider)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.checklistLabel)
                            .font(theme.typography.caption.weight(.medium).monospaced())
                            .foregroundStyle(theme.colorTextPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let match = InvoiceProductTemplateMatcher.bestMatch(for: row.description, in: scopedTemplates) {
                            Text("Suggerito: \(match.name)")
                                .font(theme.typography.caption2)
                                .foregroundStyle(theme.colorSuccess)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isOn ? theme.colorPrimary.opacity(0.08) : theme.colorSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isOn ? theme.colorPrimary.opacity(0.4) : theme.colorDivider.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                beginEditRow(row)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.colorPrimary)
                    .padding(.top, 10)
                    .padding(.trailing, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modifica riga")
        }
    }

    private func beginEditRow(_ row: InvoiceLineItem) {
        editCode = row.productCode ?? ""
        editLot = row.lotCode ?? ""
        editDescription = row.description
        editingRow = row
    }

    private func invoiceRowEditorSheet(_ row: InvoiceLineItem) -> some View {
        NavigationStack {
            Form {
                Section("Correggi trascrizione") {
                    TextField("Codice", text: $editCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Lotto", text: $editLot)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Descrizione", text: $editDescription, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Text("Modifica solo se l’OCR ha letto male. Il testo verrà usato così com’è per il lotto in ingresso.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .navigationTitle("Modifica riga")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { editingRow = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveEditedRow(id: row.id) }
                        .disabled(editDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveEditedRow(id: UUID) {
        guard var extraction else {
            editingRow = nil
            return
        }
        let code = editCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let lot = editLot.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else { return }

        if let index = extraction.rows.firstIndex(where: { $0.id == id }) {
            extraction.rows[index].productCode = code.isEmpty ? nil : code
            extraction.rows[index].lotCode = lot.isEmpty ? nil : lot
            extraction.rows[index].description = desc
            self.extraction = extraction
        }
        editingRow = nil
        HapticManager.shared.notification(.success)
    }

    // MARK: - Item camera / review

    private var itemCameraLayer: some View {
        ZStack {
            FullScreenLotCameraView(
                camera: camera,
                isProcessing: false,
                sessionPhotoCount: sessionItems.count,
                onCapture: { camera.capturePhoto() }
            )
            .ignoresSafeArea()

            VStack {
                if let item = currentQueueItem {
                    headerBar(
                        title: "Foto alimento \(queueIndex + 1)/\(selectedQueue.count)",
                        subtitle: "\(item.line.description) · Lotto \(item.line.displayLot)"
                    )
                }
                Spacer()
                Text("Scatta la foto dell’alimento / etichetta. Il lotto arriva dalla fattura; la scadenza non è obbligatoria.")
                    .font(theme.typography.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 110)
            }
        }
    }

    private func itemReviewLayer(_ pending: PendingLottoCapture) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let uiImage = UIImage(data: pending.photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let item = currentQueueItem {
                        Label("Da fattura: \(item.line.description)", systemImage: "doc.text")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Codice lotto")
                                .font(theme.typography.caption.weight(.semibold))
                            Spacer()
                            Text("Da documento · opzionale")
                                .font(.caption2)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                        TextField("Lotto", text: $lotDraft)
                            .font(theme.typography.title3.weight(.semibold).monospaced())
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(theme.colorSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Alimento in ingresso")
                                .font(theme.typography.caption.weight(.semibold))
                            Spacer()
                            Button("+ Aggiungi") { showAddIncomingFood = true }
                                .font(theme.typography.caption.weight(.semibold))
                        }
                        TraceabilityInlineSearchField(placeholder: "Cerca alimento…", text: $foodSearchText)
                        LazyVStack(spacing: 6) {
                            ForEach(filteredTemplates.prefix(12)) { template in
                                Button {
                                    selectedTemplate = template
                                } label: {
                                    HStack {
                                        Text(template.name)
                                            .font(theme.typography.subheadline)
                                            .foregroundStyle(theme.colorTextPrimary)
                                        Spacer()
                                        if selectedTemplate?.id == template.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(theme.colorPrimary)
                                        }
                                    }
                                    .padding(10)
                                    .background(
                                        selectedTemplate?.id == template.id
                                            ? theme.colorPrimary.opacity(0.1)
                                            : theme.colorSurface
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fornitore")
                            .font(theme.typography.caption.weight(.semibold))
                        TextField("Nome fornitore", text: $supplierName)
                            .padding(12)
                            .background(theme.colorSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    DisclosureGroup("Scadenza (opzionale)", isExpanded: $showOptionalExpiry) {
                        Toggle("Imposta scadenza", isOn: $expiryEnabled)
                            .font(theme.typography.caption)
                        if expiryEnabled {
                            DatePicker("Scadenza", selection: $expiryDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                    }
                    .font(theme.typography.caption.weight(.semibold))
                }
                .padding()
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Conferma alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Scarta") {
                        pendingCapture = nil
                        phase = .shootItem
                        camera.resetCaptureBuffer()
                        camera.start()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(queueIndex + 1 < selectedQueue.count ? "Conferma e avanti" : "Conferma") {
                        confirmCurrentItem(pending)
                    }
                    .disabled(selectedTemplate == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Associate

    private var associateSheet: some View {
        TraceabilityAssociateProductionSheet(
            primaryRecords: sessionRecords,
            restaurantId: restaurantId,
            productions: productions.filter { $0.restaurantId == restaurantId },
            categories: categories.filter { $0.restaurantId == restaurantId },
            onConfirm: { production, extraIds, dishPhoto in
                associate(production: production, extraIds: extraIds, dishPhoto: dishPhoto)
            },
            onCancel: {
                showAssociateSheet = false
                // Lascia i lotti in «Da associare»
                onUpdated()
                closeFlow()
            }
        )
    }

    // MARK: - Header

    private func headerBar(title: String, subtitle: String) -> some View {
        HStack {
            Button {
                closeFlow()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.45), in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(theme.typography.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Actions

    private func handleDocumentPhoto(_ data: Data) {
        isExtracting = true
        documentPhotoData = data
        camera.stop()
        Task {
            do {
                let result = try await extractor.extract(from: data)
                await MainActor.run {
                    isExtracting = false
                    guard result.isRecognizedDocument else {
                        errorMessage = "Non sembra una fattura o un DDT. Inquadra il documento con la tabella prodotti e riprova."
                        camera.resetCaptureBuffer()
                        camera.start()
                        return
                    }
                    if result.rows.isEmpty {
                        errorMessage = "Documento riconosciuto (\(result.documentKind.label)), ma nessuna riga prodotto trovata. Riprova con una foto più nitida della tabella."
                        camera.resetCaptureBuffer()
                        camera.start()
                        return
                    }
                    extraction = result
                    selectedLineIds = []
                    supplierName = result.supplierName ?? ""
                    phase = .selectRows
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    isExtracting = false
                    errorMessage = error.localizedDescription
                    camera.resetCaptureBuffer()
                    camera.start()
                }
            }
        }
    }

    private func beginItemCaptureQueue() {
        guard let extraction else { return }
        let lines = extraction.rows.filter { selectedLineIds.contains($0.id) }
        guard !lines.isEmpty else { return }

        selectedQueue = lines.map { line in
            let match = InvoiceProductTemplateMatcher.bestMatch(for: line.description, in: scopedTemplates)
            return InvoiceSelectedLine(
                line: line,
                suggestedTemplateId: match?.id,
                suggestedTemplateName: match?.name
            )
        }
        queueIndex = 0
        sessionId = UUID()
        sessionItems = []
        sessionRecords = []
        pendingCapture = nil
        prepareItemForm(for: selectedQueue[0])
        phase = .shootItem
        camera.resetCaptureBuffer()
        camera.start()
    }

    private func prepareItemForm(for item: InvoiceSelectedLine) {
        lotDraft = item.line.lotCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        foodSearchText = ""
        showOptionalExpiry = false
        expiryEnabled = item.line.expiryDate != nil
        if let expiry = item.line.expiryDate {
            expiryDate = expiry
        }
        if let id = item.suggestedTemplateId {
            selectedTemplate = scopedTemplates.first { $0.id == id }
        } else {
            selectedTemplate = nil
            foodSearchText = item.line.description
        }
        if supplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            supplierName = extraction?.supplierName ?? ""
        }
    }

    private func handleItemPhoto(_ data: Data) {
        let pending = lottoService.makePendingCapture(photoData: data)
        var ready = pending
        ready.isLotExtracting = false
        ready.lotDraft = lotDraft
        ready.testoLottoOCR = lotDraft.isEmpty ? nil : lotDraft
        pendingCapture = ready
        phase = .reviewItem
        camera.stop()
    }

    private func confirmCurrentItem(_ pending: PendingLottoCapture) {
        guard let template = selectedTemplate else {
            errorMessage = "Seleziona un alimento in ingresso."
            return
        }
        do {
            var capture = pending
            capture.lotDraft = lotDraft
            if expiryEnabled {
                capture.labelExpiryDate = expiryDate
                capture.expiryFromLabel = false
            }
            let lotto = try lottoService.confirmCapture(
                pending: capture,
                template: template,
                supplier: supplierName,
                expiryDate: expiryEnabled ? expiryDate : nil,
                expiryFromLabel: false,
                expiryUserEdited: expiryEnabled,
                acceptedDespiteExpired: false,
                sessionId: sessionId,
                user: user,
                modelContext: modelContext
            )
            TraceabilitySupplierMemory.remember(supplierName, restaurantId: restaurantId)
            sessionItems.append(lotto)
            if let record = lottoService.traceabilityRecord(for: lotto, modelContext: modelContext) {
                sessionRecords.append(record)
            }
            pendingCapture = nil
            onUpdated()
            HapticManager.shared.notification(.success)

            let next = queueIndex + 1
            if next < selectedQueue.count {
                queueIndex = next
                prepareItemForm(for: selectedQueue[next])
                phase = .shootItem
                camera.resetCaptureBuffer()
                camera.start()
            } else {
                camera.stop()
                showAssociateSheet = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func associate(production: Production, extraIds: Set<UUID>, dishPhoto: Data?) {
        do {
            var extras: [TraceabilityRecord] = []
            let sessionRecordIds = Set(sessionRecords.map(\.id))
            for id in extraIds where !sessionRecordIds.contains(id) {
                var descriptor = FetchDescriptor<TraceabilityRecord>(
                    predicate: #Predicate<TraceabilityRecord> { $0.id == id }
                )
                descriptor.fetchLimit = 1
                if let record = (try? modelContext.fetch(descriptor))?.first {
                    extras.append(record)
                }
            }
            try lottoService.associateWithProductions(
                lottoFotos: sessionItems,
                reusedRecords: extras,
                productions: [production],
                user: user,
                modelContext: modelContext,
                productionPhotoData: dishPhoto
            )
            showAssociateSheet = false
            onUpdated()
            HapticManager.shared.notification(.success)
            closeFlow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetToDocumentCamera() {
        extraction = nil
        selectedLineIds = []
        selectedQueue = []
        pendingCapture = nil
        phase = .shootDocument
        isExtracting = false
        camera.resetCaptureBuffer()
        camera.start()
    }

    private func closeFlow() {
        camera.stop()
        onDismiss()
    }
}
