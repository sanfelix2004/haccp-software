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
    case soonExpiring   = 2   // entro 7 giorni
    case healthy        = 3   // > 7 giorni
    case used           = 4   // già usato / archiviato
    case frozen         = 5   // congelato (no scadenza diretta)
    case rejected       = 6   // respinto

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .expired:      return "Scaduto"
        case .dueToday:     return "Scade oggi"
        case .soonExpiring: return "In scadenza"
        case .healthy:      return "Conforme"
        case .used:         return "Archiviato"
        case .frozen:       return "Congelato"
        case .rejected:     return "Respinto"
        }
    }

    var icon: String {
        switch self {
        case .expired:      return "xmark.octagon.fill"
        case .dueToday:     return "exclamationmark.octagon.fill"
        case .soonExpiring: return "clock.badge.exclamationmark.fill"
        case .healthy:      return "checkmark.seal.fill"
        case .used:         return "archivebox.fill"
        case .frozen:       return "snowflake"
        case .rejected:     return "trash.slash.fill"
        }
    }

    func color(_ tm: ThemeManager) -> Color {
        switch self {
        case .expired:      return tm.colorError
        case .dueToday:     return tm.colorError
        case .soonExpiring: return tm.colorWarning
        case .healthy:      return tm.colorSuccess
        case .used:         return tm.colorTextSecondary
        case .frozen:       return tm.colorInfo
        case .rejected:     return tm.colorTextSecondary
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

        guard let exp = record.expiryDate else { return .healthy }

        let days = ProductExpiryEvaluator.daysUntilExpiry(exp, now: now)

        if days < 0  { return .expired }
        if days == 0 { return .dueToday }
        if days <= soonThresholdDays { return .soonExpiring }
        return .healthy
    }

    /// Giorni rimanenti formattati ("Oggi", "+3g", "-2g") rispetto a `now`.
    static func daysLabel(record: TraceabilityRecord, now: Date = Date()) -> String {
        guard let exp = record.expiryDate else { return "—" }
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
    case used    = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .all:     return "Tutti"
        case .alerts:  return "Da attenzionare"
        case .expired: return "Scaduti"
        case .soon:    return "In scadenza"
        case .healthy: return "Conformi"
        case .used:    return "Archiviati"
        }
    }

    var icon: String {
        switch self {
        case .all:     return "tray.full.fill"
        case .alerts:  return "exclamationmark.triangle.fill"
        case .expired: return "xmark.octagon.fill"
        case .soon:    return "clock.badge.exclamationmark.fill"
        case .healthy: return "checkmark.seal.fill"
        case .used:    return "archivebox.fill"
        }
    }
}

// MARK: - Stats

struct ExpiryStats {
    var total: Int = 0
    var expired: Int = 0
    var dueOrSoon: Int = 0   // dueToday + soonExpiring (entro 7 gg)
    var dueToday: Int = 0
    var healthy: Int = 0

    var conformityPercent: Int {
        guard total > 0 else { return 100 }
        let nonConform = expired + dueToday
        return max(0, 100 - Int((Double(nonConform) / Double(total) * 100).rounded()))
    }
}

// MARK: - Root view

struct ExpiryControlView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var allRecords: [TraceabilityRecord]
    @Query private var users: [LocalUser]

    @State private var searchText: String = ""
    @State private var category: GoodsCategory = .all
    @State private var filter: ExpiryFilter = .all
    @State private var withdrawRecord: TraceabilityRecord?
    @State private var showLoginRequiredAlert = false

    private let expiryService = TraceabilityExpiryService()

    private var soonThresholdDays: Int {
        SettingsStorageService.shared.haccp.productExpiryThreshold
    }

    // MARK: Derived data

    private var scoped: [TraceabilityRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return allRecords.filter { $0.restaurantId == rid }
    }

    /// Solo prodotti rilevanti per il monitoraggio scadenze.
    /// Esclude record archiviati (used) dalle aggregazioni di rischio,
    /// ma li mantiene visibili nel filtro "Archiviati".
    private var activeRecords: [TraceabilityRecord] {
        scoped.filter { $0.productStatus != .used && $0.productStatus != .rejected }
    }

    private var stats: ExpiryStats {
        var s = ExpiryStats()
        s.total = activeRecords.count
        for r in activeRecords {
            switch ExpiryStatus.compute(record: r, soonThresholdDays: soonThresholdDays) {
            case .expired:                       s.expired += 1
            case .dueToday:                      s.dueToday += 1; s.dueOrSoon += 1
            case .soonExpiring:                  s.dueOrSoon += 1
            case .healthy, .frozen:              s.healthy += 1
            case .used, .rejected:               break
            }
        }
        return s
    }

    private var alertRecords: [TraceabilityRecord] {
        scoped
            .filter { record in
                let st = ExpiryStatus.compute(record: record, soonThresholdDays: soonThresholdDays)
                return st == .expired || st == .dueToday
            }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private var withdrawableAlertRecords: [TraceabilityRecord] {
        alertRecords.filter(\.canBeWithdrawn)
    }

    private var filteredRecords: [TraceabilityRecord] {
        scoped
            .filter { record in
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
                case .alerts:  if st != .expired && st != .dueToday && st != .soonExpiring { return false }
                case .expired: if st != .expired && st != .dueToday { return false }
                case .soon:    if st != .soonExpiring { return false }
                case .healthy: if st != .healthy && st != .frozen { return false }
                case .used:    if st != .used && st != .rejected { return false }
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
            .sorted { a, b in
                let sa = ExpiryStatus.compute(record: a, soonThresholdDays: soonThresholdDays).rawValue
                let sb = ExpiryStatus.compute(record: b, soonThresholdDays: soonThresholdDays).rawValue
                if sa != sb { return sa < sb }
                return (a.expiryDate ?? .distantFuture) < (b.expiryDate ?? .distantFuture)
            }
    }

    // MARK: Body

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private func presentWithdraw(for record: TraceabilityRecord) {
        guard record.canBeWithdrawn else { return }
        guard currentUser != nil else {
            showLoginRequiredAlert = true
            return
        }
        withdrawRecord = record
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {

                header

                summaryRow

                if !alertRecords.isEmpty {
                    alertSection
                }

                filterBar

                listSection
            }
            .padding(theme.spacing.xl)
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Controllo scadenze")
        .navigationBarTitleDisplayMode(.inline)
        .animation(theme.motion.standard, value: searchText)
        .animation(theme.motion.standard, value: category)
        .animation(theme.motion.standard, value: filter)
        .animation(theme.motion.standard, value: scoped.count)
        .sheet(item: $withdrawRecord) { record in
            if let user = currentUser {
                TraceabilityWithdrawSheet(
                    record: record,
                    user: user,
                    onSaved: { withdrawRecord = nil },
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
        .alert("Accesso richiesto", isPresented: $showLoginRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Effettua l'accesso per registrare ritiro o scarto.")
        }
        .task(id: appState.activeRestaurantId) {
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
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colorTextPrimary)
                Text("Monitoraggio automatico prodotti e conformità HACCP")
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

    // MARK: Summary cards

    private var summaryRow: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: theme.spacing.md)],
            spacing: theme.spacing.md
        ) {
            ExpirySummaryCard(
                icon: "tray.full.fill",
                title: "Prodotti totali",
                value: "\(stats.total)",
                tint: theme.colorInfo,
                hint: stats.total == 0 ? "Nessun lotto attivo" : "Tracciabili in linea"
            )
            ExpirySummaryCard(
                icon: "clock.badge.exclamationmark.fill",
                title: "In scadenza",
                value: "\(stats.dueOrSoon)",
                tint: theme.colorWarning,
                hint: stats.dueOrSoon > 0 ? "Entro \(soonThresholdDays) giorni" : "Tutto a norma"
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
                Text("Attenzione immediata")
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
                ForEach(alertRecords.prefix(5)) { record in
                    Button {
                        presentWithdraw(for: record)
                    } label: {
                        ExpiryAlertRow(
                            record: record,
                            showsWithdrawHint: record.canBeWithdrawn
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if withdrawableAlertRecords.count > 0 {
                Text("Tocca un lotto scaduto per registrare ritiro o scarto.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }

            if alertRecords.count > 5 {
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

            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.sm) {
                    ForEach(GoodsCategory.allCases) { c in
                        FilterChip(
                            label: c.rawValue,
                            icon: nil,
                            isSelected: category == c
                        ) {
                            category = c
                        }
                    }
                }
            }
        }
    }

    // MARK: List section

    private var listSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack {
                Text("Elenco prodotti")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Spacer()
                Text("\(filteredRecords.count) elementi")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }

            if filteredRecords.isEmpty {
                ExpiryEmptyState(
                    isNoData: scoped.isEmpty,
                    onReset: {
                        searchText = ""
                        category = .all
                        filter = .all
                    }
                )
            } else {
                LazyVStack(spacing: theme.spacing.sm) {
                    ForEach(filteredRecords) { record in
                        Button {
                            presentWithdraw(for: record)
                        } label: {
                            ExpiryProductRow(
                                record: record,
                                soonThresholdDays: soonThresholdDays,
                                showsWithdrawHint: record.canBeWithdrawn
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
    var showsWithdrawHint: Bool = false

    private var status: ExpiryStatus { ExpiryStatus.compute(record: record) }
    private var color: Color { status.color(theme) }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: status.icon)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(record.productName)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(1)
                HStack(spacing: theme.spacing.sm) {
                    Text("Lotto \(record.lotCode)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    Text("·")
                        .foregroundStyle(theme.colorTextSecondary)
                    Text(record.supplier)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .lineLimit(1)
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
    var soonThresholdDays: Int = HACCPSettings().productExpiryThreshold
    var showsWithdrawHint: Bool = false

    private var status: ExpiryStatus {
        ExpiryStatus.compute(record: record, soonThresholdDays: soonThresholdDays)
    }
    private var color: Color { status.color(theme) }
    private var categoryLabel: String {
        GoodsCategory(rawValue: record.categoryRaw ?? "")?.rawValue ?? "Senza categoria"
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {

            // Status indicator (left vertical bar)
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.productName)
                    .font(theme.typography.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colorTextPrimary)
                    .lineLimit(1)

                HStack(spacing: theme.spacing.sm) {
                    metaTag(icon: "number", text: "Lotto \(record.lotCode)")
                    metaTag(icon: "shippingbox.fill", text: record.supplier)
                }

                HStack(spacing: theme.spacing.sm) {
                    metaTag(icon: "tag.fill", text: categoryLabel)
                    if let prod = record.productionReference, !prod.isEmpty {
                        metaTag(icon: "fork.knife", text: prod)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                ExpiryStatusBadge(status: status)

                Text(ExpiryStatus.daysLabel(record: record))
                    .font(theme.typography.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(color)

                if let exp = record.expiryDate {
                    Text(exp, format: .dateTime.day().month(.abbreviated).year())
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                if showsWithdrawHint {
                    Text("Tocca per ritiro/scarto")
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

    private func metaTag(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(theme.colorTextSecondary)
            Text(text)
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Badge

private struct ExpiryStatusBadge: View {
    @Environment(\.theme) private var theme
    let status: ExpiryStatus

    var body: some View {
        let color = status.color(theme)
        return HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.label)
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
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: theme.spacing.md) {
            Image(systemName: isNoData ? "tray.fill" : "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(theme.colorTextSecondary)
                .padding(theme.spacing.md)
                .background(
                    Circle().fill(theme.colorSurfaceElevated)
                )
            VStack(spacing: theme.spacing.xs) {
                Text(isNoData ? "Nessun lotto registrato" : "Nessun risultato")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                Text(isNoData
                     ? "Aggiungi una registrazione da Ricezione merci o Tracciabilità: comparirà qui con stato e giorni rimanenti."
                     : "Modifica i filtri o la ricerca per visualizzare altri prodotti.")
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
