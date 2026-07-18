import SwiftUI
import SwiftData

struct HistoryModuleDetailView: View {
    let module: HistoryModule
    let entries: [HistoryEntry]
    var onDataChanged: (() -> Void)? = nil

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query private var users: [LocalUser]
    @StateObject private var vm = HistoryModuleDetailViewModel()
    @State private var visibleCount = PerformanceConfig.historyPageSize
    @State private var withdrawRecord: TraceabilityRecord?
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var entryPendingRemoval: HistoryEntry?
    @State private var removalError: String?

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var masterUser: LocalUser? {
        users.first { $0.role == .master }
    }

    private var permissions: UserPermissions {
        currentUser?.permissions ?? UserPermissions(role: .viewer)
    }

    private var canManageHistory: Bool {
        permissions.can(.manageHistory)
    }

    private var filteredEntries: [HistoryEntry] {
        vm.filtered(entries: entries).sorted { $0.date > $1.date }
    }

    private var visibleEntries: [HistoryEntry] {
        Array(filteredEntries.prefix(visibleCount))
    }

    private var groupedEntries: [(date: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: visibleEntries) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    private var hasMore: Bool {
        visibleCount < filteredEntries.count
    }

    private var criticalCount: Int {
        filteredEntries.filter(\.hasCriticality).count
    }

    private var accent: Color {
        module.accentColor(theme: theme)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                moduleHeader
                if canManageHistory, module == .traceability {
                    historyControlHint
                }
                filtersCard

                if filteredEntries.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna registrazione",
                        message: "Non ci sono dati per questo modulo nel periodo o con i filtri selezionati.",
                        actionTitle: nil
                    ))
                    .padding(.vertical, 24)
                } else {
                    timelineContent
                    if hasMore {
                        loadMoreButton
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(module.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.appliedFilter) { _, _ in
            visibleCount = PerformanceConfig.historyPageSize
        }
        .sheet(item: $withdrawRecord) { record in
            if let user = currentUser {
                TraceabilityWithdrawSheet(
                    record: record,
                    user: user,
                    onSaved: {
                        withdrawRecord = nil
                        onDataChanged?()
                    },
                    onCancel: { withdrawRecord = nil }
                )
            }
        }
        .masterAuthCover(coordinator: masterAuth, master: masterUser)
        .alert(
            "Nascondi dallo storico?",
            isPresented: Binding(
                get: { entryPendingRemoval != nil },
                set: { if !$0 { entryPendingRemoval = nil } }
            )
        ) {
            Button("Annulla", role: .cancel) { entryPendingRemoval = nil }
            Button("Nascondi", role: .destructive) {
                confirmHistoryRemoval()
            }
        } message: {
            Text("La voce sparisce dallo storico operativo, ma resta nei Documenti con tutti i movimenti. Operazione riservata al MASTER.")
        }
        .alert("Operazione non riuscita", isPresented: Binding(
            get: { removalError != nil },
            set: { if !$0 { removalError = nil } }
        )) {
            Button("OK", role: .cancel) { removalError = nil }
        } message: {
            Text(removalError ?? "")
        }
    }

    private var historyControlHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(theme.colorPrimary)
            Text("Swipe a sinistra per nascondere una produzione o un lotto dallo storico. Nei Documenti ogni traccia resta permanente.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func openPendingClosure(recordId: UUID) {
        let targetId = recordId
        var descriptor = FetchDescriptor<TraceabilityRecord>(
            predicate: #Predicate<TraceabilityRecord> { record in
                record.id == targetId
            }
        )
        descriptor.fetchLimit = 1
        guard let record = (try? modelContext.fetch(descriptor))?.first else { return }
        withdrawRecord = record
    }

    private func handlePendingClosure(recordId: UUID) {
        guard module == .expiryControl else { return }
        openPendingClosure(recordId: recordId)
    }

    private func requestHistoryRemoval(_ entry: HistoryEntry) {
        guard entry.allowsHistoryRemoval else { return }
        masterAuth.request(permission: .manageHistory, permissions: permissions) {
            entryPendingRemoval = entry
        }
    }

    private func confirmHistoryRemoval() {
        guard let entry = entryPendingRemoval,
              let user = currentUser else {
            entryPendingRemoval = nil
            return
        }
        entryPendingRemoval = nil
        do {
            let control = HistoryControlService()
            if let batchId = entry.produzioneBatchId {
                var descriptor = FetchDescriptor<ProduzioneBatch>(
                    predicate: #Predicate<ProduzioneBatch> { $0.id == batchId }
                )
                descriptor.fetchLimit = 1
                guard let batch = (try? modelContext.fetch(descriptor))?.first else {
                    removalError = "Produzione non trovata."
                    return
                }
                try control.removeProductionFromHistory(
                    batch: batch,
                    user: user,
                    modelContext: modelContext
                )
            } else if let recordId = entry.historyRemovalRecordId {
                var descriptor = FetchDescriptor<TraceabilityRecord>(
                    predicate: #Predicate<TraceabilityRecord> { $0.id == recordId }
                )
                descriptor.fetchLimit = 1
                guard let record = (try? modelContext.fetch(descriptor))?.first else {
                    removalError = "Voce di tracciabilità non trovata."
                    return
                }
                try control.softDeleteTraceabilityRecord(
                    record: record,
                    user: user,
                    modelContext: modelContext
                )
            } else {
                removalError = "Voce non eliminabile."
                return
            }
            onDataChanged?()
        } catch {
            removalError = error.localizedDescription
        }
    }

    private var moduleHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: module.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(module.rawValue)
                    .font(theme.typography.title3.weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("\(filteredEntries.count) registrazioni nel periodo")
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HistoryMiniStat(label: "Totale", value: "\(filteredEntries.count)")
                HistoryMiniStat(label: "Criticità", value: "\(criticalCount)", highlight: criticalCount > 0)
                HistoryMiniStat(
                    label: "Operatori",
                    value: "\(Set(filteredEntries.map(\.operatorName)).count)"
                )
            }
            HistoryFilterBar(filter: $vm.filter, entries: entries)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Timeline")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)

            ForEach(groupedEntries, id: \.date) { group in
                HistoryDateSection(
                    date: group.date,
                    entries: group.entries,
                    onPendingClosure: handlePendingClosure,
                    canRemoveFromHistory: canManageHistory && module == .traceability,
                    onRemoveFromHistory: requestHistoryRemoval
                )
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            visibleCount += PerformanceConfig.historyPageSize
        } label: {
            Label(
                "Carica altre \(min(PerformanceConfig.historyPageSize, filteredEntries.count - visibleCount))",
                systemImage: "arrow.down.circle.fill"
            )
            .font(theme.typography.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(PremiumPressButtonStyle())
    }
}

private struct HistoryMiniStat: View {
    let label: String
    let value: String
    var highlight: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(theme.typography.headline.weight(.bold))
                .foregroundStyle(highlight ? theme.colorError : theme.colorTextPrimary)
            Text(label)
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
