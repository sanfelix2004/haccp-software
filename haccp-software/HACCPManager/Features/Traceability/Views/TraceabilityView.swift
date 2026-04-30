import SwiftUI
import SwiftData

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

    @State private var selectedTraceabilityForProduction: TraceabilityRecord?
    @State private var showProductionSelection = false
    @State private var pendingProductionIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var selectedStatus: ProductStatus?
    @State private var selectedDateFilter: DateFilter = .all
    @State private var nonComplianceRecord: TraceabilityRecord?
    @State private var nonComplianceNote = ""
    @State private var editRecord: TraceabilityRecord?
    @State private var editProductName = ""
    @State private var editSupplier = ""
    @State private var editLotCode = ""
    @State private var editReceivedAt = Date()
    @State private var editExpiryDate = Date()
    @State private var editIncludeExpiry = false
    @State private var editNotes = ""
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
                record.productName.localizedCaseInsensitiveContains(searchText)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DashboardCardView(title: "Tracciabilita") {
                    VStack(spacing: 10) {
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
                                            Text(record.productName).foregroundColor(.white)
                                            Text("Lotto: \(record.lotCode.isEmpty ? "-" : record.lotCode)")
                                                .font(.caption).foregroundColor(.gray)
                                            Text("Fornitore: \(record.supplier.isEmpty ? "-" : record.supplier)")
                                                .font(.caption).foregroundColor(.gray)
                                            Text("Ricezione: \(record.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption2).foregroundColor(.gray)
                                            statusBadge(for: record.productStatus)
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
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.orange)
                                        .disabled(record.productStatus == .rejected)

                                        Button("Modifica") {
                                            editRecord = record
                                            editProductName = record.productName
                                            editSupplier = record.supplier
                                            editLotCode = record.lotCode
                                            editReceivedAt = record.receivedAt
                                            editIncludeExpiry = record.expiryDate != nil
                                            editExpiryDate = record.expiryDate ?? Date()
                                            editNotes = record.notes ?? ""
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.white)

                                        Button("Elimina", role: .destructive) {
                                            do {
                                                try service.deleteRecord(
                                                    record: record,
                                                    links: links,
                                                    logs: logs,
                                                    images: images,
                                                    modelContext: modelContext
                                                )
                                            } catch {
                                                errorMessage = "Eliminazione non riuscita."
                                            }
                                        }
                                        .buttonStyle(.bordered)
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
        .sheet(isPresented: Binding(get: { editRecord != nil }, set: { if !$0 { editRecord = nil } })) {
            editSheet
        }
    }

    @ViewBuilder
    private var nonComplianceSheet: some View {
        NavigationStack {
            Form {
                Section("Non conformita") {
                    TextField("Motivo", text: $nonComplianceNote, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { nonComplianceRecord = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let record = nonComplianceRecord else { return }
                        let note = nonComplianceNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !note.isEmpty else { return }
                        do {
                            try service.markNonCompliant(
                                record: record,
                                note: note,
                                imageData: nil,
                                operatorName: currentUser?.name ?? "Operatore",
                                modelContext: modelContext
                            )
                            nonComplianceRecord = nil
                        } catch {
                            errorMessage = "Salvataggio non conformita non riuscito."
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var editSheet: some View {
        NavigationStack {
            Form {
                Section("Modifica storico tracciabilita") {
                    TextField("Prodotto", text: $editProductName)
                    TextField("Fornitore", text: $editSupplier)
                    TextField("N lotto", text: $editLotCode)
                    DatePicker("Data e ora", selection: $editReceivedAt)
                    Toggle("Data scadenza", isOn: $editIncludeExpiry)
                    if editIncludeExpiry {
                        DatePicker("Scadenza", selection: $editExpiryDate, displayedComponents: .date)
                    }
                    TextField("Note", text: $editNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { editRecord = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let record = editRecord else { return }
                        do {
                            try service.updateRecord(
                                record: record,
                                productName: editProductName,
                                supplier: editSupplier,
                                lotCode: editLotCode,
                                receivedAt: editReceivedAt,
                                expiryDate: editIncludeExpiry ? editExpiryDate : nil,
                                notes: editNotes,
                                modelContext: modelContext
                            )
                            editRecord = nil
                        } catch {
                            errorMessage = "Modifica non riuscita."
                        }
                    }
                }
            }
        }
    }

    private func associatedProductions(for record: TraceabilityRecord) -> [Production] {
        let productionIds = Set(links.filter { $0.receivedItemId == record.id }.map(\.productionId))
        return productions.filter { productionIds.contains($0.id) }.sorted { $0.name < $1.name }
    }

    @ViewBuilder
    private func statusBadge(for status: ProductStatus) -> some View {
        Text(status.label)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(status))
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
        if let first = recordImages.first, let image = UIImage(data: first.imageData) {
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
