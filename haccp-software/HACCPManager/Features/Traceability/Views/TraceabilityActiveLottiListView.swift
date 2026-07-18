import SwiftUI
import SwiftData

// MARK: - TraceabilityActiveLottiListView
// Schermata che mostra tutti gli alimenti con i lotti scannerizzati
// ancora attivi (non scaduti o scaduti da al massimo 5 giorni).

struct TraceabilityActiveLottiListView: View {
    let restaurantId: UUID
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var records: [TraceabilityRecord] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedRecordForDetail: IdentifiableUUID? = nil

    private var filteredRecords: [TraceabilityRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return records }
        return records.filter {
            $0.productName.lowercased().contains(query)
            || $0.lotCode.lowercased().contains(query)
            || $0.supplier.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Caricamento lotti attivi…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if records.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun lotto attivo",
                        message: "Non ci sono lotti scannerizzati non scaduti (o scaduti di recente) in magazzino.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 0) {
                        // Barra di ricerca
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(theme.colorTextSecondary)
                            TextField("Cerca per alimento, lotto o fornitore…", text: $searchText)
                                .font(theme.typography.body)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(theme.colorTextSecondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(theme.colorSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        // Lista dei lotti
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredRecords) { record in
                                    LottoActiveRow(record: record) {
                                        selectedRecordForDetail = IdentifiableUUID(id: record.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Lotti attivi in magazzino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi", action: onDismiss)
                }
            }
            .sheet(item: $selectedRecordForDetail) { wrapper in
                TraceabilityRecordHistoryDetailSheet(recordId: wrapper.id) {
                    selectedRecordForDetail = nil
                }
            }
            .task {
                loadRecords()
            }
        }
    }

    private func loadRecords() {
        let rid = restaurantId
        let now = Date()
        
        // Calcola la data di 5 giorni fa per includere i lotti scaduti da pochi giorni
        let limitDate = Calendar.current.date(byAdding: .day, value: -5, to: now) ?? now

        let descriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> {
                $0.restaurantId == rid
            },
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []

        records = all.filter { record in
            // Deve essere un ingrediente in ingresso (non una produzione)
            guard record.isIncomingIngredientLot else { return false }
            // Esclude i lotti archiviati/usati completamente o respinti
            guard record.productStatus != .used,
                  record.productStatus != .rejected else { return false }
            
            // Verifica la scadenza: non scaduto OPPURE scaduto da al massimo 5 giorni
            if let expiry = record.expiryDate {
                return expiry >= limitDate
            }
            // Se non ha scadenza, consideralo valido
            return true
        }

        isLoading = false
    }
}

// MARK: - LottoActiveRow

private struct LottoActiveRow: View {
    let record: TraceabilityRecord
    let onTap: () -> Void

    @Environment(\.theme) private var theme

    private var isExpired: Bool {
        if let expiry = record.expiryDate {
            return expiry < Date()
        }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icona o miniatura
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isExpired ? theme.colorError.opacity(0.12) : theme.colorPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "shippingbox.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isExpired ? theme.colorError : theme.colorPrimary)
                }

                // Info lotto
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.productName)
                        .font(theme.typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("Lotto \(record.lotCode)")
                            .font(theme.typography.caption2.weight(.bold).monospaced())
                            .foregroundStyle(theme.colorPrimary)

                        if let expiry = record.expiryDate {
                            Text("Scad: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                .font(theme.typography.caption2)
                                .foregroundStyle(isExpired ? theme.colorError : theme.colorTextSecondary)
                        }
                    }

                    if !record.supplier.isEmpty {
                        Text(record.supplier)
                            .font(theme.typography.caption2)
                            .foregroundStyle(theme.colorTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Stato / Indicatori
                VStack(alignment: .trailing, spacing: 6) {
                    if isExpired {
                        HACCPBadge(title: "Scaduto", style: .nonConforme, showIcon: false)
                    } else {
                        HACCPBadge(title: "Attivo", style: .conforme, showIcon: false)
                    }
                    
                    Text(record.receivedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .padding(12)
            .background(theme.colorSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isExpired ? theme.colorError.opacity(0.25) : theme.colorDivider.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
