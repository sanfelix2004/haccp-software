import SwiftUI
import SwiftData

// MARK: - TraceabilityIngredientReusePanel
// Pannello embedded nella schermata di selezione piatto per riutilizzare
// lotti già registrati in precedenza senza dover scattare una nuova foto.

struct TraceabilityIngredientReusePanel: View {
    let restaurantId: UUID
    /// IDs dei LottoFoto già nella sessione corrente (da escludere dal pannello)
    let sessionLottoIds: Set<UUID>
    /// IDs dei record già selezionati per il riutilizzo
    @Binding var selectedRecordIds: Set<UUID>
    /// Record da tenere sempre visibili (es. alimento in associazione).
    var pinnedRecordIds: Set<UUID> = []
    /// Apri già espanso (es. «Usa solo dal magazzino»).
    var startExpanded: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var availableRecords: [TraceabilityRecord] = []
    @State private var searchText = ""
    @State private var isExpanded = false
    @State private var didApplyInitialExpand = false

    private var filteredRecords: [TraceabilityRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return availableRecords }
        return availableRecords.filter {
            $0.productName.lowercased().contains(query)
            || $0.lotCode.lowercased().contains(query)
            || $0.supplier.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header / toggle collapsibile
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(theme.colorPrimary.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "archivebox.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.colorPrimary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Alimenti già in magazzino")
                            .font(theme.typography.subheadline.weight(.semibold))
                            .foregroundStyle(theme.colorTextPrimary)
                        Text("\(availableRecords.count) lotti non scaduti disponibili")
                            .font(theme.typography.caption2)
                            .foregroundStyle(theme.colorTextSecondary)
                    }

                    Spacer()

                    // Badge selezione
                    if !selectedRecordIds.isEmpty {
                        Text("\(selectedRecordIds.count)")
                            .font(theme.typography.caption.weight(.bold))
                            .foregroundStyle(theme.colorTextOnPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.colorPrimary)
                            .clipShape(Capsule())
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colorTextSecondary)
                }
                .padding(12)
                .background(theme.colorSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            selectedRecordIds.isEmpty
                                ? theme.colorDivider.opacity(0.6)
                                : theme.colorPrimary.opacity(0.4),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)

            // Corpo espanso
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Campo ricerca
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.footnote)
                            .foregroundStyle(theme.colorTextSecondary)
                        TextField("Cerca per nome, lotto o fornitore…", text: $searchText)
                            .font(theme.typography.caption)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(theme.colorTextSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(theme.colorSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if filteredRecords.isEmpty {
                        Text(searchText.isEmpty
                             ? "Nessun lotto riutilizzabile trovato."
                             : "Nessun risultato per «\(searchText)».")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(filteredRecords) { record in
                                ReuseRecordRow(
                                    record: record,
                                    isSelected: selectedRecordIds.contains(record.id),
                                    onToggle: { toggleRecord(record) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .task {
            if startExpanded, !didApplyInitialExpand {
                isExpanded = true
                didApplyInitialExpand = true
            }
            loadAvailableRecords()
        }
    }

    // MARK: - Actions

    private func toggleRecord(_ record: TraceabilityRecord) {
        if selectedRecordIds.contains(record.id) {
            selectedRecordIds.remove(record.id)
        } else {
            selectedRecordIds.insert(record.id)
        }
        HapticManager.shared.selection()
    }

    private func loadAvailableRecords() {
        let rid = restaurantId
        let now = Date()

        let descriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> {
                $0.restaurantId == rid && !$0.isArchived
            },
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let sessionLottoFotoIds = sessionLottoIds

        // Magazzino = lotti ancora Disponibili (anche se già associati a un piatto).
        // Fuori: chiusi (usato/scartato), scaduti, produzioni finite, foto già in sessione.
        availableRecords = all.filter { record in
            if pinnedRecordIds.contains(record.id) { return true }

            guard record.isIncomingIngredientLot else { return false }
            guard record.productStatus == .available else { return false }
            if let expiry = record.expiryDate,
               ProductExpiryEvaluator.isExpiredByDate(expiry, now: now) {
                return false
            }
            if let lottoId = record.lottoFotoId, sessionLottoFotoIds.contains(lottoId) {
                return false
            }
            return true
        }
    }
}

// MARK: - ReuseRecordRow

private struct ReuseRecordRow: View {
    let record: TraceabilityRecord
    let isSelected: Bool
    let onToggle: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? theme.colorPrimary : theme.colorSurface)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.colorTextOnPrimary)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.colorDivider, lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                    }
                }

                // Info prodotto
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.productName)
                        .font(theme.typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if !record.lotCode.isEmpty {
                            Text("Lotto \(record.lotCode)")
                                .font(theme.typography.caption2.weight(.bold).monospaced())
                                .foregroundStyle(theme.colorPrimary)
                        }

                        if let expiry = record.expiryDate {
                            let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
                            let expiryColor: Color = daysLeft <= 3 ? theme.colorWarning : theme.colorTextSecondary
                            Text("Scade \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                .font(theme.typography.caption2)
                                .foregroundStyle(expiryColor)
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

                // Indicatore già usato in una produzione
                if record.productionReference != nil {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(theme.colorSuccess.opacity(0.8))
                        .help("Già usato in una produzione precedente")
                }
            }
            .padding(10)
            .background(
                isSelected
                    ? theme.colorPrimary.opacity(0.08)
                    : theme.colorSurfaceElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? theme.colorPrimary.opacity(0.4) : theme.colorDivider.opacity(0.5),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
