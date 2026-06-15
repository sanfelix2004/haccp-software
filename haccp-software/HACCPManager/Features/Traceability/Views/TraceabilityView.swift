import SwiftUI
import SwiftData
import AVFoundation
import Combine

struct TraceabilityView: View {
    enum DateFilter: String, CaseIterable, Identifiable {
        case all = "Tutte le date"
        case today = "Oggi"
        case month = "Ultimo mese"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @StateObject private var dataStore = TraceabilityDataStore()

    @State private var selectedTraceabilityForProduction: TraceabilityRecord?
    @State private var showProductionSelection = false
    @State private var pendingProductionIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var selectedStatus: ProductStatus?
    @State private var selectedDateFilter: DateFilter = .all
    @State private var nonComplianceRecord: TraceabilityRecord?
    @State private var nonComplianceNote = ""
    @State private var nonComplianceCorrectiveAction = ""
    @State private var nonCompliancePhotoData: Data?
    @State private var ncAwaitingCapture = false
    @StateObject private var ncCamera = FinalizeReceiptCameraViewModel()
    @State private var showMasterAuthDelete = false
    @State private var recordPendingDelete: TraceabilityRecord?
    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var labelDraft: ProductionLabelDraft?

    private let productionLibraryService = ProductionLibraryService()
    private let expiryService = TraceabilityExpiryService()
    private let service = TraceabilityService()
    private let labelService = ProductionLabelsService()

    private var scopedRecords: [TraceabilityRecord] {
        dataStore.records
    }

    private var filteredRecords: [TraceabilityRecord] {
        scopedRecords.filter { record in
            let searchOk = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                displayProductName(for: record).localizedCaseInsensitiveContains(searchText)
            let statusOk = selectedStatus == nil || record.productStatus == selectedStatus
            let dateOk: Bool = {
                switch selectedDateFilter {
                case .all: return true
                case .today: return Calendar.current.isDateInToday(record.createdAt)
                case .month: return record.createdAt >= Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
                }
            }()
            return searchOk && statusOk && dateOk
        }
    }

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var isMaster: Bool { currentUser?.role == .master }

    private var scopedGoodsReceipts: [GoodsReceipt] {
        dataStore.goodsReceipts
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DashboardCardView(title: "Tracciabilità") {
                    VStack(spacing: 10) {
                        Text("Le modifiche al prodotto si effettuano da Ricezione merci.")
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            appState.navigateToGoodsReceiving = true
                        } label: {
                            Label("Aggiungi da Ricezione merci", systemImage: "shippingbox.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.colorPrimary)
                        HStack(spacing: 8) {
                            TextField("Cerca prodotto", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                            Picker("Stato", selection: Binding(
                                get: { selectedStatus?.rawValue ?? "ALL" },
                                set: { selectedStatus = ProductStatus(rawValue: $0) }
                            )) {
                                Text("Tutti").tag("ALL")
                                ForEach(ProductStatus.allCases, id: \.rawValue) { status in
                                    Text(status.label).tag(status.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            Picker("Data", selection: $selectedDateFilter) {
                                ForEach(DateFilter.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.menu)
                            Button("Esporta CSV") { exportURL = buildExportFile() }
                                .buttonStyle(.bordered)
                                .tint(ThemeManager.shared.colorPrimary)
                        }
                        if let exportURL {
                            HStack {
                                Spacer()
                                ShareLink(item: exportURL) {
                                    Label("Condividi export", systemImage: "square.and.arrow.up")
                                }
                                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                            }
                        }
                    }

                    if filteredRecords.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessun prodotto in tracciabilità",
                            message: "Ricevi merci per popolare lo storico e gestire stato/produzioni.",
                            actionTitle: nil
                        ))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredRecords.prefix(80)) { record in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        recordImagePreview(for: record)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(displayProductName(for: record)).foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                            Text("Lotto: \(displayLot(for: record))")
                                                .font(.caption).foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                            Text("Fornitore: \(displaySupplier(for: record))")
                                                .font(.caption).foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                            Text("Ricezione: \(displayReceivedAt(for: record).formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption2).foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                            if let cat = displayCategoryLabel(for: record) {
                                                Text("Categoria: \(cat)")
                                                    .font(.caption2)
                                                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                            }
                                            if let st = displayReceiptStatusLabel(for: record) {
                                                Text("Stato ricezione: \(st)")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.colorWarning)
                                            }
                                            Text("Scadenza: \(displayExpiry(for: record))")
                                                .font(.caption2)
                                                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                            statusBadge(for: record)
                                            let associated = associatedProductions(for: record)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Produzioni associate")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(theme.colorTextSecondary)
                                                Text(associated.isEmpty ? "Nessuna produzione" : associated.map(\.name).joined(separator: " • "))
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(associated.isEmpty ? theme.colorTextSecondary : theme.colorSuccess)
                                                    .lineLimit(2)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(associated.isEmpty ? theme.colorSurface : theme.colorSuccess.opacity(0.14))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(associated.isEmpty ? theme.colorDivider : theme.colorSuccess.opacity(0.5), lineWidth: 1)
                                            )
                                            let defrostUses = dataStore.defrostRecords.filter { $0.traceabilityItemId == record.id }
                                            if !defrostUses.isEmpty {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Decongelamento")
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(theme.colorTextSecondary)
                                                    ForEach(defrostUses) { defrost in
                                                        Text("Usato in decongelamento · \(defrost.method) · \(defrost.defrostStatus.label)")
                                                            .font(.caption.weight(.semibold))
                                                            .foregroundStyle(ThemeManager.shared.colorInfo)
                                                    }
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(ThemeManager.shared.colorInfo.opacity(0.12))
                                                )
                                            }
                                            if record.isNonCompliant {
                                                if let reason = record.nonComplianceNote, !reason.isEmpty {
                                                    Text("Criticità: \(reason)")
                                                        .font(.caption2)
                                                        .foregroundStyle(ThemeManager.shared.colorWarning)
                                                }
                                                if let cap = record.nonComplianceCorrectiveAction, !cap.isEmpty {
                                                    Text("Azione: \(cap)")
                                                        .font(.caption2)
                                                        .foregroundStyle(theme.colorWarning)
                                                }
                                            }
                                        }
                                        Spacer()
                                    }

                                    HStack {
                                        Button("Associa a una produzione") {
                                            selectedTraceabilityForProduction = record
                                            pendingProductionIds = Set(dataStore.links.filter { $0.receivedItemId == record.id }.map(\.productionId))
                                            showProductionSelection = true
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(ThemeManager.shared.colorPrimary)
                                        .disabled(record.productStatus == .expired || record.productStatus == .rejected)

                                        if record.productStatus != .rejected {
                                            CreateProductionLabelLink {
                                                labelDraft = labelService.draft(from: record)
                                            }
                                        }

                                        Button("Segna non conforme") {
                                            nonComplianceRecord = record
                                            nonComplianceNote = ""
                                            nonComplianceCorrectiveAction = ""
                                            nonCompliancePhotoData = nil
                                            ncCamera.resetCaptureBuffer()
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(theme.colorWarning)
                                        .disabled(record.productStatus == .rejected)

                                        if isMaster {
                                            Button("Elimina", role: .destructive) {
                                                recordPendingDelete = record
                                                showMasterAuthDelete = true
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    if record.productStatus == .expired || record.productStatus == .rejected {
                                        Text("Prodotto non associabile a produzioni (scaduto o non conforme).")
                                            .font(.caption2)
                                            .foregroundStyle(ThemeManager.shared.colorWarning)
                                    }
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
        .navigationTitle("Tracciabilità")
        .task(id: appState.activeRestaurantId) {
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
        .onAppear {
            let expired = expiryService.refreshStatuses(records: scopedRecords, modelContext: modelContext)
            if expired > 0 {
                errorMessage = "Sono stati marcati \(expired) prodotti come scaduti."
                dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
            }
        }
        .alert("Tracciabilità", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showProductionSelection) {
            ProductionSelectionView(
                initialSelectedIds: pendingProductionIds,
                onCancel: { showProductionSelection = false },
                onConfirm: { selectedProductions in
                    guard let record = selectedTraceabilityForProduction else { return }
                    do {
                        try productionLibraryService.syncAssociations(
                            record: record,
                            selectedProductions: selectedProductions,
                            operatorName: currentUser?.name ?? "Operatore",
                            links: dataStore.links,
                            modelContext: modelContext
                        )
                        dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
                        showProductionSelection = false
                    } catch {
                        errorMessage = "Associazione produzione non riuscita."
                    }
                }
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: Binding(get: { nonComplianceRecord != nil }, set: { if !$0 { nonComplianceRecord = nil } })) {
            nonComplianceSheet
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
        .onReceive(ncCamera.$capturedPhotoData) { data in
            guard ncAwaitingCapture, let data, !data.isEmpty else { return }
            ncAwaitingCapture = false
            nonCompliancePhotoData = data
            ncCamera.stop()
        }
        .fullScreenCover(isPresented: $showMasterAuthDelete) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .deleteTraceabilityEntry,
                    onAuthorized: {
                        showMasterAuthDelete = false
                        if let record = recordPendingDelete {
                            do {
                                try service.deleteTraceabilityEntry(
                                    record: record,
                                    goodsReceipts: scopedGoodsReceipts,
                                    links: dataStore.links,
                                    logs: dataStore.logs,
                                    images: dataStore.images,
                                    modelContext: modelContext
                                )
                            } catch {
                                errorMessage = "Eliminazione non riuscita."
                            }
                            recordPendingDelete = nil
                        }
                    },
                    onCancel: {
                        showMasterAuthDelete = false
                        recordPendingDelete = nil
                    }
                ) { EmptyView() }
            }
        }
    }

    private func receiptForTrace(_ record: TraceabilityRecord) -> GoodsReceipt? {
        guard let gid = record.goodsReceiptId else { return nil }
        return scopedGoodsReceipts.first { $0.id == gid }
    }

    private func displayProductName(for record: TraceabilityRecord) -> String {
        receiptForTrace(record)?.productNameSnapshot ?? record.productName
    }

    private func displaySupplier(for record: TraceabilityRecord) -> String {
        let s = receiptForTrace(record)?.supplierNameSnapshot ?? record.supplier
        return s.isEmpty ? "-" : s
    }

    private func displayLot(for record: TraceabilityRecord) -> String {
        let lot = receiptForTrace(record)?.lotNumber ?? (record.lotCode.isEmpty ? nil : record.lotCode)
        guard let lot, !lot.isEmpty else { return "-" }
        return lot
    }

    private func displayReceivedAt(for record: TraceabilityRecord) -> Date {
        receiptForTrace(record)?.receivedAt ?? record.receivedAt
    }

    private func displayCategoryLabel(for record: TraceabilityRecord) -> String? {
        if let r = receiptForTrace(record) {
            return r.category.rawValue
        }
        if let raw = record.categoryRaw {
            return GoodsCategory(rawValue: raw)?.rawValue ?? raw
        }
        return nil
    }

    private func displayExpiry(for record: TraceabilityRecord) -> String {
        if let d = receiptForTrace(record)?.expiryDate ?? record.expiryDate {
            return d.formatted(date: .abbreviated, time: .omitted)
        }
        return "-"
    }

    private func displayReceiptStatusLabel(for record: TraceabilityRecord) -> String? {
        guard let receipt = receiptForTrace(record) else { return nil }
        return receipt.status.label
    }

    @ViewBuilder
    private var nonComplianceSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Motivo, azione correttiva e foto sono obbligatori per registrare una criticità.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Motivo (non conformità)") {
                    TextField("Es. confezione danneggiata, temperatura errata…", text: $nonComplianceNote, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Azione correttiva") {
                    TextField("Cosa fate per gestire la criticità", text: $nonComplianceCorrectiveAction, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Foto obbligatoria") {
                    if let data = nonCompliancePhotoData,
                       let preview = HACCPZoomablePhotoPreview(data: data, height: 220, zoomTitle: "Foto non conformità") {
                        preview
                        Button("Riscatta foto") {
                            nonCompliancePhotoData = nil
                            ncCamera.resetCaptureBuffer()
                            ncCamera.start()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ThemeManager.shared.colorCameraPreviewBackground)
                            .frame(height: 160)
                            .overlay(
                                Group {
                                    if ncCamera.authorizationDenied {
                                        Text("Accesso fotocamera negato")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        FinalizeCameraSessionPreview(session: ncCamera.session)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            )
                        Button("Scatta foto") {
                            ncAwaitingCapture = true
                            ncCamera.capturePhoto()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(ncCamera.authorizationDenied)
                    }
                }
            }
            .navigationTitle("Non conformità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        ncAwaitingCapture = false
                        ncCamera.stop()
                        nonComplianceRecord = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") {
                        guard let record = nonComplianceRecord else { return }
                        guard let user = currentUser else {
                            errorMessage = "Effettua l'accesso per registrare la non conformità."
                            return
                        }
                        let note = nonComplianceNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        let action = nonComplianceCorrectiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !note.isEmpty, !action.isEmpty, let photo = nonCompliancePhotoData, photo.isEmpty == false else {
                            errorMessage = "Per una non conformità è obbligatorio allegare una foto."
                            return
                        }
                        do {
                            try service.markNonCompliant(
                                record: record,
                                note: note,
                                correctiveAction: action,
                                imageData: photo,
                                user: user,
                                modelContext: modelContext
                            )
                            ncAwaitingCapture = false
                            ncCamera.stop()
                            nonComplianceRecord = nil
                            nonCompliancePhotoData = nil
                        } catch {
                            errorMessage = (error as NSError).localizedDescription
                        }
                    }
                }
            }
            .onAppear {
                ncCamera.resetCaptureBuffer()
                ncCamera.start()
            }
            .onDisappear {
                ncAwaitingCapture = false
                ncCamera.stop()
            }
        }
    }

    private func associatedProductions(for record: TraceabilityRecord) -> [Production] {
        let productionIds = Set(dataStore.links.filter { $0.receivedItemId == record.id }.map(\.productionId))
        return dataStore.productions.filter { productionIds.contains($0.id) }.sorted { $0.name < $1.name }
    }

    @ViewBuilder
    private func statusBadge(for record: TraceabilityRecord) -> some View {
        let label = record.isNonCompliant ? "Non conforme" : record.productStatus.label
        let style: HACCPBadgeStyle = record.isNonCompliant ? .nonConforme : badgeStyle(record.productStatus)
        HACCPBadge(title: label, style: style, showIcon: false)
    }

    private func badgeStyle(_ status: ProductStatus) -> HACCPBadgeStyle {
        switch status {
        case .available: return .info
        case .partiallyUsed: return .warning
        case .used: return .conforme
        case .expired: return .nonConforme
        case .rejected: return .nonConforme
        }
    }

    private func buildExportFile() -> URL? {
        let csv = service.exportTraceabilityReport(records: filteredRecords, links: dataStore.links, productions: dataStore.productions)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("traceability_report.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            errorMessage = "Export non riuscito."
            return nil
        }
    }

    @ViewBuilder
    private func recordImagePreview(for record: TraceabilityRecord) -> some View {
        if let image = traceabilityUIImage(for: record) {
            HACCPZoomablePhotoThumbnail(
                image: image,
                size: 56,
                zoomTitle: displayProductName(for: record)
            )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemeManager.shared.colorSurface)
                .frame(width: 56, height: 56)
                .overlay(Text("Nessuna foto").font(.caption2).foregroundStyle(ThemeManager.shared.colorTextSecondary))
        }
    }

    private func traceabilityUIImage(for record: TraceabilityRecord) -> UIImage? {
        let recordImages = dataStore.images.filter { $0.receivedItemId == record.id }.sorted { $0.createdAt > $1.createdAt }
        let preferred = recordImages.first { $0.type == .nonComplianceRequired }
            ?? recordImages.first { $0.type == .receiptOptional }
            ?? recordImages.first
        if let imgModel = preferred,
           let bytes = imgModel.imageData, !bytes.isEmpty,
           let image = UIImage(data: bytes) {
            return image
        }
        if let path = preferred?.localPath, let image = UIImage(contentsOfFile: path) {
            return image
        }
        if let data = receiptForTrace(record)?.photoData, let image = UIImage(data: data) {
            return image
        }
        if let data = record.photoData, let image = UIImage(data: data) {
            return image
        }
        return nil
    }
}
