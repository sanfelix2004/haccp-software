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
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var records: [TraceabilityRecord]
    @Query private var productions: [Production]
    @Query private var links: [TraceabilityLink]
    @Query private var logs: [TraceabilityLog]
    @Query private var images: [ProductImage]
    @Query private var goodsReceipts: [GoodsReceipt]

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

    private let productionLibraryService = ProductionLibraryService()
    private let expiryService = TraceabilityExpiryService()
    private let service = TraceabilityService()

    private var scopedRecords: [TraceabilityRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
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
        guard let rid = appState.activeRestaurantId else { return [] }
        return goodsReceipts.filter { $0.restaurantId == rid }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DashboardCardView(title: "Tracciabilita") {
                    VStack(spacing: 10) {
                        Text("Le modifiche al prodotto si effettuano da Ricezione merci.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            appState.navigateToGoodsReceiving = true
                        } label: {
                            Label("Aggiungi da Ricezione merci", systemImage: "shippingbox.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
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
                                .tint(.white)
                        }
                        if let exportURL {
                            HStack {
                                Spacer()
                                ShareLink(item: exportURL) {
                                    Label("Condividi export", systemImage: "square.and.arrow.up")
                                }
                                .foregroundColor(.white)
                            }
                        }
                    }

                    if filteredRecords.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessun prodotto in tracciabilita",
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
                                            Text(displayProductName(for: record)).foregroundColor(.white)
                                            Text("Lotto: \(displayLot(for: record))")
                                                .font(.caption).foregroundColor(.gray)
                                            Text("Fornitore: \(displaySupplier(for: record))")
                                                .font(.caption).foregroundColor(.gray)
                                            Text("Ricezione: \(displayReceivedAt(for: record).formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption2).foregroundColor(.gray)
                                            if let cat = displayCategoryLabel(for: record) {
                                                Text("Categoria: \(cat)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                            if let st = displayReceiptStatusLabel(for: record) {
                                                Text("Stato ricezione: \(st)")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange.opacity(0.95))
                                            }
                                            Text("Scadenza: \(displayExpiry(for: record))")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            statusBadge(for: record)
                                            let associated = associatedProductions(for: record)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("PRODUZIONI ASSOCIATE")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundColor(.white.opacity(0.95))
                                                Text(associated.isEmpty ? "Nessuna produzione" : associated.map(\.name).joined(separator: " • "))
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(associated.isEmpty ? .gray : .green)
                                                    .lineLimit(2)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(associated.isEmpty ? Color.white.opacity(0.05) : Color.green.opacity(0.14))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(associated.isEmpty ? Color.white.opacity(0.12) : Color.green.opacity(0.5), lineWidth: 1)
                                            )
                                            if record.isNonCompliant {
                                                if let reason = record.nonComplianceNote, !reason.isEmpty {
                                                    Text("Criticità: \(reason)")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                }
                                                if let cap = record.nonComplianceCorrectiveAction, !cap.isEmpty {
                                                    Text("Azione: \(cap)")
                                                        .font(.caption2)
                                                        .foregroundColor(.yellow.opacity(0.9))
                                                }
                                            }
                                        }
                                        Spacer()
                                    }

                                    HStack {
                                        Button("Associa a una produzione") {
                                            selectedTraceabilityForProduction = record
                                            pendingProductionIds = Set(links.filter { $0.receivedItemId == record.id }.map(\.productionId))
                                            showProductionSelection = true
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.white)
                                        .disabled(record.productStatus == .expired || record.productStatus == .rejected)

                                        Button("Segna non conforme") {
                                            nonComplianceRecord = record
                                            nonComplianceNote = ""
                                            nonComplianceCorrectiveAction = ""
                                            nonCompliancePhotoData = nil
                                            ncCamera.resetCaptureBuffer()
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.orange)
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
                                            .foregroundColor(.yellow)
                                    }
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
        .navigationTitle("Tracciabilita")
        .onAppear {
            let expired = expiryService.refreshStatuses(records: scopedRecords, modelContext: modelContext)
            if expired > 0 {
                errorMessage = "Sono stati marcati \(expired) prodotti come scaduti."
            }
        }
        .alert("Tracciabilita", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
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
                            links: links,
                            modelContext: modelContext
                        )
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
        .onReceive(ncCamera.$capturedPhotoData) { data in
            guard ncAwaitingCapture, let data, data.isEmpty == false else { return }
            ncAwaitingCapture = false
            nonCompliancePhotoData = data
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
                                    links: links,
                                    logs: logs,
                                    images: images,
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.85))
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
                    if nonCompliancePhotoData != nil {
                        Label("Foto acquisita", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
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
        let productionIds = Set(links.filter { $0.receivedItemId == record.id }.map(\.productionId))
        return productions.filter { productionIds.contains($0.id) }.sorted { $0.name < $1.name }
    }

    @ViewBuilder
    private func statusBadge(for record: TraceabilityRecord) -> some View {
        let label = record.isNonCompliant ? "Non conforme" : record.productStatus.label
        Text(label)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(record.productStatus))
            .cornerRadius(8)
    }

    private func statusColor(_ status: ProductStatus) -> Color {
        switch status {
        case .available: return .blue.opacity(0.7)
        case .partiallyUsed: return .orange.opacity(0.8)
        case .used: return .green.opacity(0.8)
        case .expired: return .red.opacity(0.9)
        case .rejected: return .red
        }
    }

    private func buildExportFile() -> URL? {
        let csv = service.exportTraceabilityReport(records: scopedRecords, links: links, productions: productions)
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
        let recordImages = images.filter { $0.receivedItemId == record.id }.sorted { $0.createdAt > $1.createdAt }
        let preferred = recordImages.first { $0.type == .nonComplianceRequired }
            ?? recordImages.first { $0.type == .receiptOptional }
            ?? recordImages.first
        if let imgModel = preferred,
           let bytes = imgModel.imageData, bytes.isEmpty == false,
           let image = UIImage(data: bytes) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
        } else if let path = preferred?.localPath, let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
        } else if let data = receiptForTrace(record)?.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
        } else if let data = record.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .frame(width: 56, height: 56)
                .overlay(Text("Nessuna foto").font(.caption2).foregroundColor(.gray))
        }
    }
}
