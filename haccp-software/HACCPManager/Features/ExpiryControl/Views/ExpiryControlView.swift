//
//  ExpiryControlView.swift
//  HACCP Manager — Modulo Controllo Scadenze
//
//  Dashboard enterprise per il monitoraggio scadenze prodotti.
//  Token-driven: usa ThemeManager per ogni colore/spaziatura, niente hard-coded.
//

import SwiftUI
import SwiftData

// MARK: - Status

/// Stato derivato dalla data di scadenza + stato prodotto.
enum ExpiryStatus: Int, CaseIterable, Identifiable {
    case expired        = 0   // scaduto
    case dueToday       = 1   // scade oggi
    case soonExpiring   = 2   // entro soglia impostazioni
    case healthy        = 3   // oltre soglia
    case used           = 4   // già usato / archiviato
    case frozen         = 5   // congelato (no scadenza diretta)
    case rejected       = 6   // respinto
    case missingExpiry  = 7   // senza data — usa al più presto

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .expired:       return "Scaduto"
        case .dueToday:      return "Scade oggi"
        case .soonExpiring:  return "In scadenza"
        case .healthy:       return "Conforme"
        case .used:          return "Chiuso"
        case .frozen:        return "Congelato"
        case .rejected:      return "Respinto"
        case .missingExpiry: return "Senza scadenza"
        }
    }

    var icon: String {
        switch self {
        case .expired:       return "xmark.octagon.fill"
        case .dueToday:      return "exclamationmark.octagon.fill"
        case .soonExpiring:  return "clock.badge.exclamationmark.fill"
        case .healthy:       return "checkmark.seal.fill"
        case .used:          return "archivebox.fill"
        case .frozen:        return "snowflake"
        case .rejected:      return "trash.slash.fill"
        case .missingExpiry: return "photo.on.rectangle.angled"
        }
    }

    func color(_ tm: ThemeManager) -> Color {
        switch self {
        case .expired:       return tm.colorError
        case .dueToday:      return tm.colorError
        case .soonExpiring:  return tm.colorWarning
        case .healthy:       return tm.colorSuccess
        case .used:          return tm.colorTextSecondary
        case .frozen:        return tm.colorInfo
        case .rejected:      return tm.colorTextSecondary
        case .missingExpiry: return tm.colorWarning
        }
    }

    /// Hint operativo sotto il badge (cucina).
    var chefHint: String {
        switch self {
        case .expired:       return "Azione immediata"
        case .dueToday:      return "Usa oggi"
        case .soonExpiring:  return "Usa a breve"
        case .healthy:       return "Sotto controllo"
        case .used:          return "Chiuso"
        case .frozen:        return "Conservazione congelata"
        case .rejected:      return "Non utilizzabile"
        case .missingExpiry: return "Usa al più presto · controlla la foto"
        }
    }

    static func compute(
        record: TraceabilityRecord,
        now: Date = Date(),
        soonThresholdDays: Int = HACCPSettings().productExpiryThreshold
    ) -> ExpiryStatus {
        if record.productStatus == .rejected { return .rejected }
        if record.productStatus == .used     { return .used }
        if record.productStatus == .expired  { return .expired }

        // Cold-chain frozen items con scadenza opzionale: trattati come "frozen"
        if let cat = GoodsCategory(rawValue: record.categoryRaw ?? ""),
           (cat == .frozen || cat == .frozenProducts),
           record.expiryDate == nil {
            return .frozen
        }

        guard let exp = record.expiryDate else { return .missingExpiry }

        let days = ProductExpiryEvaluator.daysUntilExpiry(exp, now: now)

        if days < 0  { return .expired }
        if days == 0 { return .dueToday }
        if days <= soonThresholdDays { return .soonExpiring }
        return .healthy
    }

    /// Giorni rimanenti formattati ("Oggi", "+3g", "-2g") rispetto a `now`.
    static func daysLabel(record: TraceabilityRecord, now: Date = Date()) -> String {
        if record.expiryDate == nil {
            let status = compute(record: record, now: now)
            if status == .frozen { return "—" }
            return "N/D"
        }
        guard let exp = record.expiryDate else { return "N/D" }
        let days = ProductExpiryEvaluator.daysUntilExpiry(exp, now: now)
        if days == 0 { return "Oggi" }
        return days > 0 ? "+\(days)g" : "\(days)g"
    }
}

// MARK: - Filtri

enum ExpiryFilter: Int, CaseIterable, Identifiable {
    case all     = 0
    case alerts  = 1
    case expired = 2
    case soon    = 3
    case healthy = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .all:     return "Tutti"
        case .alerts:  return "Da attenzionare"
        case .expired: return "Scaduti"
        case .soon:    return "In scadenza"
        case .healthy: return "Conformi"
        }
    }

    var icon: String {
        switch self {
        case .all:     return "tray.full.fill"
        case .alerts:  return "exclamationmark.triangle.fill"
        case .expired: return "xmark.octagon.fill"
        case .soon:    return "clock.badge.exclamationmark.fill"
        case .healthy: return "checkmark.seal.fill"
        }
    }
}

/// Area operativa Controllo scadenze — solo produzioni.
enum ExpiryControlTab: String, CaseIterable, Identifiable {
    case production = "Produzioni"

    var id: String { rawValue }

    var icon: String { "fork.knife" }

    var subtitle: String {
        "Preparazioni salvate — tieni quelle valide, chiudi scaduti, termina o scarta con motivazione"
    }

    var actionHint: String {
        "Scadenza · Termina · Scarto · Chiudi scaduti"
    }
}

// MARK: - Stats

struct ExpiryStats {
    var total: Int = 0
    var expired: Int = 0
    var dueOrSoon: Int = 0   // dueToday + soonExpiring + missingExpiry
    var dueToday: Int = 0
    var missingExpiry: Int = 0
    var healthy: Int = 0

    var conformityPercent: Int {
        guard total > 0 else { return 100 }
        let atRisk = expired + dueOrSoon
        return max(0, 100 - Int((Double(atRisk) / Double(total) * 100).rounded()))
    }
}

// MARK: - Root view

struct ExpiryControlView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]

    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.expiryControl

    @State private var searchText: String = ""
    @State private var category: GoodsCategory = .all
    @State private var filter: ExpiryFilter = .alerts
    @State private var selectedTab: ExpiryControlTab = .production
    @State private var withdrawRecord: TraceabilityRecord?
    @State private var closureRecord: TraceabilityRecord?
    @State private var showLoginRequiredAlert = false
    @State private var masterAuth = MasterAuthCoordinator()

    private let expiryService = TraceabilityExpiryService()

    private var soonThresholdDays: Int {
        SettingsStorageService.shared.haccp.productExpiryThreshold
    }

    private var lottoById: [UUID: LottoFoto] {
        HACCPSafeParse.dictionary(dataStore.lottoFotos.map { ($0.id, $0) })
    }

    private func expirySourceLabel(for record: TraceabilityRecord) -> String? {
        TraceabilityRecordSupport.expirySourceLabel(for: record, lottoById: lottoById)
    }

    private func photoData(for record: TraceabilityRecord) -> Data? {
        // Produzioni: niente foto in Controllo scadenze.
        _ = record
        return nil
    }

    // MARK: Derived data

    private var scoped: [TraceabilityRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return dataStore.records.filter {
            $0.restaurantId == rid && TraceabilityRecordSupport.isExpiryMonitored($0)
        }
    }

    private var tabScoped: [TraceabilityRecord] {
        scoped.filter(TraceabilityRecordSupport.isProductionExpiryRecord)
    }

    private func alertCount(in records: [TraceabilityRecord]) -> Int {
        records.filter {
            ProductExpiryEvaluator.needsExpiryAttention($0, thresholdDays: soonThresholdDays)
        }.count
    }

    /// Aperti (non ancora chiusi). I chiusi in grace restano in lista ma fuori dalle stats operative.
    private var activeRecords: [TraceabilityRecord] {
        tabScoped.filter { !TraceabilityRecordSupport.isOperationallyClosed($0) }
    }

    private var stats: ExpiryStats {
        var s = ExpiryStats()
        s.total = activeRecords.count
        for r in activeRecords {
            switch ExpiryStatus.compute(record: r, soonThresholdDays: soonThresholdDays) {
            case .expired:                       s.expired += 1
            case .dueToday:                      s.dueToday += 1; s.dueOrSoon += 1
            case .soonExpiring:                  s.dueOrSoon += 1
            case .missingExpiry:                 s.missingExpiry += 1; s.dueOrSoon += 1
            case .healthy, .frozen:              s.healthy += 1
            case .used, .rejected:               break
            }
        }
        return s
    }

    private var alertRecords: [TraceabilityRecord] {
        ProductExpiryEvaluator.fefoSorted(
            tabScoped.filter { record in
                ProductExpiryEvaluator.needsExpiryAttention(record, thresholdDays: soonThresholdDays)
            },
            soonThresholdDays: soonThresholdDays
        )
    }

    private var withdrawableAlertRecords: [TraceabilityRecord] {
        alertRecords.filter(\.canBeWithdrawn)
    }

    /// Scaduti da chiudere (Usato/Scartato) nella lista filtrata corrente.
    private var toCloseRecords: [TraceabilityRecord] {
        filteredRecords.filter(\.canBeWithdrawn)
    }

    /// Ancora in validità (non scaduti / non chiusi) nella lista filtrata.
    private var keepRecords: [TraceabilityRecord] {
        filteredRecords.filter {
            !$0.canBeWithdrawn && !TraceabilityRecordSupport.isOperationallyClosed($0)
        }
    }

    private var filteredRecords: [TraceabilityRecord] {
        let filtered = tabScoped.filter { record in
                // Categoria
                if category != .all {
                    guard let raw = record.categoryRaw,
                          let c = GoodsCategory(rawValue: raw),
                          c == category else { return false }
                }

                // Stato
                let st = ExpiryStatus.compute(record: record, soonThresholdDays: soonThresholdDays)
                switch filter {
                case .all:     break
                case .alerts:
                    if st != .expired && st != .dueToday && st != .soonExpiring && st != .missingExpiry {
                        return false
                    }
                case .expired: if st != .expired { return false }
                case .soon:    if st != .soonExpiring && st != .missingExpiry { return false }
                case .healthy: if st != .healthy && st != .frozen { return false }
                }

                // Ricerca testo
                if !searchText.isEmpty {
                    let q = searchText.lowercased()
                    let hay = "\(record.productName) \(record.lotCode) \(record.supplier) \(record.productionReference ?? "")"
                        .lowercased()
                    if !hay.contains(q) { return false }
                }

                return true
            }
        return ProductExpiryEvaluator.fefoSorted(filtered, soonThresholdDays: soonThresholdDays)
    }

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var permissions: UserPermissions { currentUser.permissions }

    private func presentWithdraw(for record: TraceabilityRecord) {
        guard record.canBeWithdrawn else { return }
        guard currentUser != nil else {
            showLoginRequiredAlert = true
            return
        }
        masterAuth.request(permission: .executeRecords, permissions: permissions) {
            withdrawRecord = record
        }
    }

    private func presentArchive(for record: TraceabilityRecord) {
        guard currentUser != nil else {
            showLoginRequiredAlert = true
            return
        }
        masterAuth.request(permission: .executeRecords, permissions: permissions) {
            closureRecord = record
        }
    }

    private func handleClosureSaved() {
        closureRecord = nil
        KitchenProcessNotifications.postRecordsDidChange()
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    header
                    summaryRow
                    if !alertRecords.isEmpty {
                        alertSection
                    }
                    filterBar
                    listHeader
                }
                .padding(.vertical, theme.spacing.sm)
                .textCase(nil)
            }
            .listRowInsets(EdgeInsets(
                top: theme.spacing.md,
                leading: theme.spacing.xl,
                bottom: theme.spacing.sm,
                trailing: theme.spacing.xl
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(theme.colorBackground)

            if filteredRecords.isEmpty {
                Section {
                    ExpiryEmptyState(
                        isNoData: tabScoped.isEmpty,
                        tab: selectedTab,
                        onReset: {
                            searchText = ""
                            category = .all
                            filter = .all
                        }
                    )
                    .padding(.vertical, theme.spacing.lg)
                }
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: theme.spacing.xl,
                    bottom: theme.spacing.xl,
                    trailing: theme.spacing.xl
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(theme.colorBackground)
            } else {
                if !toCloseRecords.isEmpty, filter == .all || filter == .alerts || filter == .expired {
                    Section {
                        sectionTitleRow("Da chiudere (scaduti)", count: toCloseRecords.count, tint: theme.colorError)
                        ForEach(toCloseRecords) { record in
                            expiryRecordRow(record)
                                .listRowInsets(EdgeInsets(top: 5, leading: theme.spacing.xl, bottom: 5, trailing: theme.spacing.xl))
                                .listRowSeparator(.hidden)
                                .listRowBackground(theme.colorBackground)
                        }
                    }
                    .listSectionSeparator(.hidden)
                }

                if !keepRecords.isEmpty, filter != .expired {
                    Section {
                        sectionTitleRow(
                            "Da tenere (ancora valide)",
                            count: keepRecords.count,
                            tint: theme.colorSuccess
                        )
                        ForEach(keepRecords) { record in
                            expiryRecordRow(record)
                                .listRowInsets(EdgeInsets(top: 5, leading: theme.spacing.xl, bottom: 5, trailing: theme.spacing.xl))
                                .listRowSeparator(.hidden)
                                .listRowBackground(theme.colorBackground)
                        }
                    }
                    .listSectionSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Controllo scadenze")
        .navigationBarTitleDisplayMode(.inline)
        .animation(theme.motion.standard, value: searchText)
        .animation(theme.motion.standard, value: category)
        .animation(theme.motion.standard, value: filter)
        .animation(theme.motion.standard, value: selectedTab)
        .animation(theme.motion.standard, value: scoped.count)
        .sheet(item: $withdrawRecord) { record in
            if let user = currentUser {
                TraceabilityWithdrawSheet(
                    record: record,
                    user: user,
                    onSaved: {
                        withdrawRecord = nil
                        KitchenProcessNotifications.postRecordsDidChange()
                    },
                    onCancel: { withdrawRecord = nil }
                )
            } else {
                ContentUnavailableView(
                    "Accesso richiesto",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Effettua l'accesso per registrare ritiro o scarto.")
                )
            }
        }
        .sheet(item: $closureRecord) { record in
            if let user = currentUser {
                ExpiryLotClosureSheet(
                    record: record,
                    user: user,
                    isProduction: record.isProductionBatchOutput,
                    onSaved: handleClosureSaved,
                    onCancel: { closureRecord = nil }
                )
            }
        }
        .alert("Accesso richiesto", isPresented: $showLoginRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Effettua l'accesso per registrare ritiro o scarto.")
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
        .task(id: appState.activeRestaurantId) {
            guard let rid = appState.activeRestaurantId else { return }
            await Task.yield()
            dataStore.reload(context: modelContext, restaurantId: rid)
            refreshExpiredStatuses()
        }
        .onChange(of: dataStore.loadGeneration) { _, _ in
            refreshExpiredStatuses()
        }
    }

    private func refreshExpiredStatuses() {
        guard appState.activeRestaurantId != nil else { return }
        _ = expiryService.refreshStatuses(records: scoped, modelContext: modelContext)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: theme.spacing.lg) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text("Controllo scadenze")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Solo produzioni: scadenze, termini e scarti.")
                    .font(theme.typography.callout)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer()
            ModuleHelpButton(help: ModuleHelpLibrary.sidebar(.expiryControl), size: 40)
            conformityBadge
        }
    }

    private var conformityBadge: some View {
        let pct = stats.conformityPercent
        let color: Color = pct >= 95 ? theme.colorSuccess
                         : pct >= 80 ? theme.colorWarning
                         : theme.colorError
        return HStack(spacing: theme.spacing.sm) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(pct)%")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Conformità")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.sm)
        .background(theme.colorSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionTitleRow(_ title: String, count: Int, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
            Spacer()
            Text("\(count)")
                .font(theme.typography.caption.weight(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.15)))
        }
        .listRowInsets(EdgeInsets(top: 12, leading: theme.spacing.xl, bottom: 4, trailing: theme.spacing.xl))
        .listRowSeparator(.hidden)
        .listRowBackground(theme.colorBackground)
    }

    private var legendRow: some View {
        HStack(spacing: 10) {
            legendDot(theme.colorError, "Oggi/scaduto")
            legendDot(theme.colorWarning, "≤48h")
            legendDot(theme.colorSuccess, "OK")
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
        }
    }

    // MARK: Summary cards

    private var summaryRow: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: theme.spacing.md)],
            spacing: theme.spacing.md
        ) {
            ExpirySummaryCard(
                icon: "fork.knife",
                title: "Produzioni",
                value: "\(stats.total)",
                tint: theme.colorInfo,
                hint: stats.total == 0 ? "Nessuna produzione attiva" : "In controllo"
            )
            ExpirySummaryCard(
                icon: "clock.badge.exclamationmark.fill",
                title: "In scadenza",
                value: "\(stats.dueOrSoon)",
                tint: theme.colorWarning,
                hint: {
                    if stats.missingExpiry > 0 && stats.dueToday > 0 {
                        return "\(stats.dueToday) oggi · \(stats.missingExpiry) senza data"
                    }
                    if stats.missingExpiry > 0 {
                        return "\(stats.missingExpiry) senza scadenza · usa al più presto"
                    }
                    if stats.dueToday > 0 {
                        return "\(stats.dueToday) scadono oggi · entro \(soonThresholdDays) gg"
                    }
                    return stats.dueOrSoon > 0 ? "Entro \(soonThresholdDays) giorni" : "Tutto a norma"
                }()
            )
            ExpirySummaryCard(
                icon: "xmark.octagon.fill",
                title: "Scaduti",
                value: "\(stats.expired)",
                tint: theme.colorError,
                hint: withdrawableAlertRecords.count > 0
                    ? "\(withdrawableAlertRecords.count) da chiudere"
                    : (stats.expired > 0 ? "Nessuno da chiudere" : "Nessuno")
            )
            ExpirySummaryCard(
                icon: "checkmark.seal.fill",
                title: "Conformi",
                value: "\(stats.healthy)",
                tint: theme.colorSuccess,
                hint: "OK al \(stats.conformityPercent)%"
            )
        }
    }

    // MARK: Alert section

    private var alertSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(spacing: theme.spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.colorError)
                Text(withdrawableAlertRecords.count > 0
                     ? "Da chiudere"
                     : "Da attenzionare")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Spacer()
                Text("\(alertRecords.count)")
                    .font(theme.typography.caption.weight(.bold))
                    .padding(.horizontal, theme.spacing.sm)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.colorError.opacity(0.15)))
                    .foregroundStyle(theme.colorError)
            }

            VStack(spacing: theme.spacing.sm) {
                ForEach(alertRecords.prefix(8)) { record in
                    if record.canBeWithdrawn {
                        Button {
                            presentWithdraw(for: record)
                        } label: {
                            ExpiryAlertRow(
                                record: record,
                                photoData: photoData(for: record),
                                soonThresholdDays: soonThresholdDays,
                                showsWithdrawHint: true,
                                recordTypeLabel: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                                expiryProvenanceLabel: expirySourceLabel(for: record)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        ExpiryAlertRow(
                            record: record,
                            photoData: photoData(for: record),
                            soonThresholdDays: soonThresholdDays,
                            showsWithdrawHint: false,
                            recordTypeLabel: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                            expiryProvenanceLabel: expirySourceLabel(for: record)
                        )
                    }
                }
            }

            if withdrawableAlertRecords.count > 0 {
                Text("Tocca una produzione scaduta per chiuderla (Terminato o Scartato).")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else if !alertRecords.isEmpty {
                Text("Produzioni in scadenza o scadute: tocca per Termina / Scarta.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }

            if alertRecords.count > 8 {
                Button {
                    filter = .alerts
                } label: {
                    Text("Vedi tutti i \(alertRecords.count) avvisi")
                        .font(theme.typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colorError)
                        .padding(.horizontal, theme.spacing.lg)
                        .padding(.vertical, theme.spacing.sm)
                        .background(Capsule().fill(theme.colorError.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacing.lg)
        .background(theme.colorError.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .stroke(theme.colorError.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }

    // MARK: Filter bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {

            // Search field
            HStack(spacing: theme.spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.colorTextSecondary)
                TextField("Cerca prodotto, lotto, fornitore…", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundStyle(theme.colorTextPrimary)
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.md)
            .background(theme.colorSurface)
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                    .stroke(theme.colorDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))

            // Status filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.sm) {
                    ForEach(ExpiryFilter.allCases) { f in
                        FilterChip(
                            label: f.label,
                            icon: f.icon,
                            isSelected: filter == f
                        ) {
                            filter = f
                        }
                    }
                }
            }

            // Category picker rimosso: solo produzioni
        }
    }

    // MARK: List section

    private var listHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Produzioni")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Tocca un scaduto per chiuderlo · tocca un valido per Termina / Scarta")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer()
            Text("\(filteredRecords.count) elementi")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func expiryRecordRow(_ record: TraceabilityRecord) -> some View {
        if record.canBeWithdrawn {
            Button {
                presentWithdraw(for: record)
            } label: {
                ExpiryProductRow(
                    record: record,
                    photoData: photoData(for: record),
                    soonThresholdDays: soonThresholdDays,
                    showsWithdrawHint: true,
                    recordTypeLabel: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                    expiryProvenanceLabel: expirySourceLabel(for: record)
                )
            }
            .buttonStyle(.plain)
        } else if record.productStatus != .used && record.productStatus != .rejected {
            Button {
                presentArchive(for: record)
            } label: {
                ExpiryProductRow(
                    record: record,
                    photoData: photoData(for: record),
                    soonThresholdDays: soonThresholdDays,
                    showsWithdrawHint: false,
                    showsClosureHint: true,
                    recordTypeLabel: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                    expiryProvenanceLabel: expirySourceLabel(for: record)
                )
            }
            .buttonStyle(.plain)
        } else {
            ExpiryProductRow(
                record: record,
                photoData: photoData(for: record),
                soonThresholdDays: soonThresholdDays,
                showsWithdrawHint: false,
                recordTypeLabel: TraceabilityRecordSupport.expiryTypeLabel(for: record),
                expiryProvenanceLabel: expirySourceLabel(for: record)
            )
        }
    }
}

// MARK: - Summary card

private struct ExpirySummaryCard: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let value: String
    let tint: Color
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack(spacing: theme.spacing.sm) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                }
                Spacer()
            }
            Text(value)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colorTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(theme.typography.subheadline.weight(.semibold))
                .foregroundStyle(theme.colorTextPrimary)
            Text(hint)
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
                .lineLimit(1)
            // accent bar
            Rectangle()
                .fill(tint)
                .frame(height: 3)
                .clipShape(Capsule())
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorSurface)
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .stroke(theme.colorDivider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
        .shadow(
            color: Color.black.opacity(theme.appearance.reduceGraphicsEffects ? 0 : 0.08),
            radius: 8, x: 0, y: 4
        )
    }
}

// MARK: - Alert row

private struct ExpiryAlertRow: View {
    @Environment(\.theme) private var theme
    let record: TraceabilityRecord
    var photoData: Data? = nil
    var soonThresholdDays: Int = HACCPSettings().productExpiryThreshold
    var showsWithdrawHint: Bool = false
    var recordTypeLabel: String?
    var expiryProvenanceLabel: String?

    private var status: ExpiryStatus {
        ExpiryStatus.compute(record: record, soonThresholdDays: soonThresholdDays)
    }
    private var color: Color { status.color(theme) }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            expiryPhotoThumb(
                photoData: nil,
                title: record.productName,
                fallbackIcon: "fork.knife",
                fallbackTint: color,
                size: 44
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(record.productName)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(1)
                HStack(spacing: theme.spacing.sm) {
                    Text(record.isProductionBatchOutput
                         ? "Lotto produzione \(record.lotCode)"
                         : "Lotto \(record.lotCode)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    Text("·")
                        .foregroundStyle(theme.colorTextSecondary)
                    Text(record.supplier)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .lineLimit(1)
                }
                if let recordTypeLabel {
                    Text(recordTypeLabel)
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(ExpiryStatus.daysLabel(record: record))
                    .font(theme.typography.headline.monospacedDigit())
                    .foregroundStyle(color)
                if let exp = record.expiryDate {
                    Text(exp, format: .dateTime.day().month(.abbreviated))
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                } else if status == .missingExpiry {
                    Text("Usa al più presto")
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(theme.colorWarning)
                }
                if let expiryProvenanceLabel {
                    Text(expiryProvenanceLabel)
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(
                            record.isProductionBatchOutput ? theme.colorPrimary : theme.colorSuccess
                        )
                }
                if showsWithdrawHint {
                    Text("Ritiro/scarto")
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                }
            }
        }
        .padding(theme.spacing.md)
        .background(theme.colorSurface)
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }
}

// MARK: - Product row

private struct ExpiryProductRow: View {
    @Environment(\.theme) private var theme
    let record: TraceabilityRecord
    var photoData: Data? = nil
    var soonThresholdDays: Int = HACCPSettings().productExpiryThreshold
    var showsWithdrawHint: Bool = false
    var showsClosureHint: Bool = false
    var recordTypeLabel: String?
    var expiryProvenanceLabel: String?

    private var status: ExpiryStatus {
        ExpiryStatus.compute(record: record, soonThresholdDays: soonThresholdDays)
    }
    private var operationalZone: ExpiryOperationalZone {
        ProductExpiryEvaluator.operationalZone(for: record)
    }
    private var zoneColor: Color {
        switch operationalZone {
        case .critical: return theme.colorError
        case .warning: return theme.colorWarning
        case .conforming: return theme.colorSuccess
        }
    }
    private var categoryLabel: String {
        if record.isProductionBatchOutput {
            return record.categoryRaw?.isEmpty == false ? record.categoryRaw! : "Piatto preparato"
        }
        return GoodsCategory(rawValue: record.categoryRaw ?? "")?.rawValue ?? "Senza categoria"
    }

    private var lotLabel: String {
        record.isProductionBatchOutput
            ? "Lotto produzione \(record.lotCode)"
            : "Lotto \(record.lotCode)"
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {

            RoundedRectangle(cornerRadius: 2)
                .fill(zoneColor)
                .frame(width: 4, height: 56)

            expiryPhotoThumb(
                photoData: nil,
                title: record.productName,
                fallbackIcon: "fork.knife",
                fallbackTint: theme.colorPrimary,
                size: 52
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(record.productName)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(1)

                HStack(spacing: theme.spacing.sm) {
                    metaTag(icon: "number", text: lotLabel)
                    if record.isProductionBatchOutput {
                        metaTag(icon: "building.2.fill", text: "Produzione interna")
                    } else if !record.supplier.isEmpty {
                        metaTag(icon: "shippingbox.fill", text: record.supplier)
                    }
                }

                HStack(spacing: theme.spacing.sm) {
                    if let recordTypeLabel {
                        metaTag(
                            icon: record.isProductionBatchOutput ? "fork.knife" : "tray.full.fill",
                            text: recordTypeLabel,
                            emphasized: true
                        )
                    }
                    if !record.isProductionBatchOutput {
                        metaTag(icon: "tag.fill", text: categoryLabel)
                    }
                    if record.isIncomingIngredientLot,
                       let prod = record.productionReference, !prod.isEmpty {
                        metaTag(icon: "link", text: "→ \(prod)")
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                ExpiryStatusBadge(
                    status: status,
                    labelOverride: (status == .expired && record.canBeWithdrawn) ? "Da chiudere" : nil
                )

                Text(ExpiryStatus.daysLabel(record: record))
                    .font(theme.typography.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(zoneColor)

                Text(status.chefHint)
                    .font(theme.typography.caption2.weight(.semibold))
                    .foregroundStyle(zoneColor)
                    .multilineTextAlignment(.trailing)

                if let exp = record.expiryDate {
                    Text(exp, format: .dateTime.day().month(.abbreviated).year())
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                } else if status == .missingExpiry {
                    Text("Nessuna data in etichetta")
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(theme.colorWarning)
                }
                if let expiryProvenanceLabel {
                    Text(expiryProvenanceLabel)
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(
                            record.isProductionBatchOutput ? theme.colorPrimary : theme.colorSuccess
                        )
                }
                if showsWithdrawHint {
                    Text("Tocca per chiudere")
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                } else if showsClosureHint {
                    Text("Tocca per Termina / Scarta")
                        .font(theme.typography.caption2.weight(.semibold))
                        .foregroundStyle(theme.colorPrimary)
                }
            }
        }
        .padding(theme.spacing.md)
        .background(theme.colorSurface)
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorDivider, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .shadow(
            color: Color.black.opacity(theme.appearance.reduceGraphicsEffects ? 0 : 0.05),
            radius: 4, x: 0, y: 2
        )
    }

    private func metaTag(icon: String, text: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(emphasized ? theme.colorPrimary : theme.colorTextSecondary)
            Text(text)
                .font(theme.typography.caption2.weight(emphasized ? .semibold : .regular))
                .foregroundStyle(emphasized ? theme.colorPrimary : theme.colorTextSecondary)
                .lineLimit(1)
        }
    }
}

@ViewBuilder
private func expiryPhotoThumb(
    photoData: Data?,
    title: String,
    fallbackIcon: String,
    fallbackTint: Color,
    size: CGFloat
) -> some View {
    if let photoData, !photoData.isEmpty,
       let thumb = HACCPZoomablePhotoThumbnail(
        data: photoData,
        size: size,
        zoomTitle: title
       ) {
        thumb
    } else {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fallbackTint.opacity(0.12))
                .frame(width: size, height: size)
            Image(systemName: fallbackIcon)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(fallbackTint)
        }
        .accessibilityLabel("Nessuna foto")
    }
}

// MARK: - Badge

private struct ExpiryStatusBadge: View {
    @Environment(\.theme) private var theme
    let status: ExpiryStatus
    var labelOverride: String? = nil

    var body: some View {
        let color = status.color(theme)
        return HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(labelOverride ?? status.label)
                .font(theme.typography.caption2.weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    @Environment(\.theme) private var theme
    let label: String
    let icon: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.caption2) }
                Text(label)
                    .font(theme.typography.caption.weight(.semibold))
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)
            .background(
                Capsule().fill(
                    isSelected ? theme.colorPrimary : theme.colorSurface
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? theme.colorPrimary : theme.colorDivider,
                    lineWidth: 1
                )
            )
            .foregroundStyle(
                isSelected ? theme.colorTextOnPrimary : theme.colorTextSecondary
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty state

private struct ExpiryEmptyState: View {
    @Environment(\.theme) private var theme
    let isNoData: Bool
    let tab: ExpiryControlTab
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            Image(systemName: isNoData ? tab.icon : "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(theme.colorTextSecondary)
                .padding(theme.spacing.md)
                .background(
                    Circle().fill(theme.colorSurfaceElevated)
                )
            VStack(spacing: theme.spacing.xs) {
                Text(isNoData ? "Nessuna produzione da controllare" : "Nessun risultato")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text(isNoData
                     ? "Salva una produzione in Tracciabilità: comparirà qui con la scadenza calcolata."
                     : "Modifica i filtri o la ricerca.")
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !isNoData {
                Button(action: onReset) {
                    Label("Reimposta filtri", systemImage: "arrow.uturn.backward")
                        .font(theme.typography.subheadline.weight(.semibold))
                        .padding(.horizontal, theme.spacing.lg)
                        .padding(.vertical, theme.spacing.sm)
                        .background(Capsule().fill(theme.colorPrimary))
                        .foregroundStyle(theme.colorTextOnPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing.xxl)
        .background(theme.colorSurface)
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous)
                .stroke(theme.colorDivider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerLarge, style: .continuous))
    }
}
