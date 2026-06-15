import SwiftUI
import SwiftData

struct AlertsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @Query private var checklistAlerts: [ChecklistAlert]
    @Query private var temperatureAlerts: [TemperatureAlert]
    @Query private var cleaningCriticalities: [CleaningCriticality]
    @Query private var oilAlerts: [OilControlAlert]
    @Query private var defrostCriticalities: [DefrostCriticality]
    @Query private var users: [LocalUser]

    @State private var alertToResolve: UnifiedAlert?
    @State private var checklistAlertToResolve: ChecklistAlert?
    @State private var checklistCorrectiveAction = ""
    @State private var checklistResolveError: String?

    private let checklistService = ChecklistService()

    private var activeChecklistAlerts: [ChecklistAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return checklistAlerts.filter { $0.restaurantId == rid && $0.isActive }
    }
    private var activeTemperatureAlerts: [TemperatureAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return temperatureAlerts.filter { $0.restaurantId == rid && $0.isActive }
    }
    private var activeCleaningCriticalities: [CleaningCriticality] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return cleaningCriticalities.filter { $0.restaurantId == rid && !$0.isResolved }
    }
    private var activeOilAlerts: [OilControlAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return oilAlerts.filter { $0.restaurantId == rid && $0.isActive }
    }
    private var activeDefrostCriticalities: [DefrostCriticality] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return defrostCriticalities.filter { $0.restaurantId == rid && !$0.isResolved }
    }

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    // MARK: - Unified model

    private var allAlerts: [UnifiedAlert] {
        var result: [UnifiedAlert] = []

        result += activeTemperatureAlerts.map { alert in
            UnifiedAlert(
                id: alert.id,
                module: "Temperature",
                icon: "thermometer.medium",
                title: "Temperatura fuori range · \(alert.deviceName)",
                detail: alert.message,
                date: alert.createdAt,
                severity: .nonConforme,
                resolve: { resolveTemperatureAlert(alert) }
            )
        }
        result += activeCleaningCriticalities.map { c in
            UnifiedAlert(
                id: c.id,
                module: "Pulizia",
                icon: "sparkles",
                title: "Pulizia non conforme · \(c.areaName)",
                detail: "\(c.taskName) — Azione: \(c.correctiveAction)",
                date: c.createdAt,
                severity: .nonConforme,
                resolve: { resolveCriticality(c) }
            )
        }
        result += activeDefrostCriticalities.map { c in
            UnifiedAlert(
                id: c.id,
                module: "Decongelamento",
                icon: "snowflake",
                title: "Decongelamento · \(c.productName)",
                detail: "\(c.reason) — Azione: \(c.correctiveAction)",
                date: c.createdAt,
                severity: .warning,
                resolve: { resolveDefrostCriticality(c) }
            )
        }
        result += activeOilAlerts.map { alert in
            UnifiedAlert(
                id: alert.id,
                module: "Olio",
                icon: "drop.fill",
                title: "Olio critico · \(alert.oilPointName)",
                detail: alert.message,
                date: alert.createdAt,
                severity: .warning,
                resolve: { resolveOilAlert(alert) }
            )
        }
        result += activeChecklistAlerts.map { alert in
            UnifiedAlert(
                id: alert.id,
                module: "Checklist",
                icon: "checklist",
                title: alert.message,
                detail: nil,
                date: alert.createdAt,
                severity: .warning,
                checklistAlert: alert
            )
        }

        return result.sorted { $0.date > $1.date }
    }

    private var criticalCount: Int { allAlerts.filter { $0.severity == .nonConforme }.count }
    private var warningCount: Int { allAlerts.filter { $0.severity == .warning }.count }

    // MARK: - Body

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                DashboardEmptyStateView(state: .init(
                    title: "Seleziona un'attività",
                    message: "Gli avvisi sono legati al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(24)
            } else {
                mainScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Avvisi")
        .confirmationDialog(
            "Segnare come risolto?",
            isPresented: Binding(
                get: { alertToResolve != nil },
                set: { if !$0 { alertToResolve = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Segna risolto") {
                alertToResolve?.resolve?()
                alertToResolve = nil
            }
            Button("Annulla", role: .cancel) { alertToResolve = nil }
        } message: {
            Text(alertToResolve?.title ?? "")
        }
        .sheet(isPresented: Binding(
            get: { checklistAlertToResolve != nil },
            set: { if !$0 { checklistAlertToResolve = nil; checklistCorrectiveAction = "" } }
        )) {
            NavigationStack {
                Form {
                    Section("Azione correttiva") {
                        TextField("Descrivi l'azione correttiva", text: $checklistCorrectiveAction, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    if let checklistResolveError {
                        Text(checklistResolveError)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorError)
                    }
                }
                .navigationTitle("Risolvi checklist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") {
                            checklistAlertToResolve = nil
                            checklistCorrectiveAction = ""
                            checklistResolveError = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Conferma") {
                            confirmChecklistResolve()
                        }
                    }
                }
            }
        }
    }

    private var mainScroll: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                statsRow

                if allAlerts.isEmpty {
                    DashboardCardView(title: "Avvisi") {
                        DashboardEmptyStateView(state: .init(
                            title: "Tutto sotto controllo",
                            message: "Nessun avviso attivo. Gli alert di temperatura, pulizia, olio, decongelamento e checklist appariranno qui.",
                            actionTitle: nil
                        ))
                    }
                } else {
                    DashboardCardView(title: "Da gestire", subtitle: "\(allAlerts.count) avvisi attivi") {
                        LazyVStack(spacing: 10) {
                            ForEach(allAlerts) { alert in
                                AlertRowView(alert: alert) {
                                    if alert.checklistAlert != nil {
                                        checklistAlertToResolve = alert.checklistAlert
                                        checklistResolveError = nil
                                    } else if alert.resolve != nil {
                                        alertToResolve = alert
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Attivi",
                value: "\(allAlerts.count)",
                subtitle: allAlerts.isEmpty ? "Nessun avviso" : "Da gestire",
                icon: "bell.badge.fill",
                accent: allAlerts.isEmpty ? theme.colorSuccess : theme.colorPrimary
            )
            StatCard(
                title: "Critici",
                value: "\(criticalCount)",
                subtitle: "Non conformità",
                icon: "exclamationmark.octagon.fill",
                accent: criticalCount > 0 ? theme.colorError : theme.colorTextSecondary
            )
            StatCard(
                title: "Avvisi",
                value: "\(warningCount)",
                subtitle: "Da verificare",
                icon: "exclamationmark.triangle.fill",
                accent: warningCount > 0 ? theme.colorWarning : theme.colorTextSecondary
            )
        }
    }

    // MARK: - Resolve actions

    private func resolveDefrostCriticality(_ criticality: DefrostCriticality) {
        guard let user = currentUser else { return }
        criticality.isResolved = true
        criticality.resolvedAt = Date()
        criticality.resolvedByUserId = user.id
        criticality.resolvedByNameSnapshot = user.name
        try? modelContext.save()
    }

    private func resolveCriticality(_ criticality: CleaningCriticality) {
        guard let user = currentUser else { return }
        criticality.isResolved = true
        criticality.resolvedAt = Date()
        criticality.resolvedByUserId = user.id
        criticality.resolvedByNameSnapshot = user.name
        try? modelContext.save()
    }

    private func resolveTemperatureAlert(_ alert: TemperatureAlert) {
        guard let user = currentUser, let rid = appState.activeRestaurantId else { return }
        do {
            try TemperatureModuleService().resolveAlert(
                alert,
                user: user,
                restaurantId: rid,
                modelContext: modelContext
            )
        } catch {
            alert.isActive = false
            alert.resolvedAt = Date()
            try? modelContext.save()
        }
    }

    private func resolveOilAlert(_ alert: OilControlAlert) {
        guard let user = currentUser else { return }
        do {
            try OilControlService().resolveAlert(alert, user: user, modelContext: modelContext)
        } catch {
            alert.isActive = false
            alert.resolvedAt = Date()
            try? modelContext.save()
        }
    }

    private func confirmChecklistResolve() {
        guard let alert = checklistAlertToResolve, let user = currentUser else { return }
        let action = checklistCorrectiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !action.isEmpty else {
            checklistResolveError = "Azione correttiva obbligatoria."
            return
        }
        do {
            try checklistService.resolveAlert(
                alert,
                correctiveAction: action,
                user: user,
                modelContext: modelContext
            )
            checklistAlertToResolve = nil
            checklistCorrectiveAction = ""
            checklistResolveError = nil
        } catch {
            checklistResolveError = "Risoluzione non riuscita."
        }
    }
}

// MARK: - Unified alert model

private struct UnifiedAlert: Identifiable {
    let id: UUID
    let module: String
    let icon: String
    let title: String
    let detail: String?
    let date: Date
    let severity: HACCPBadgeStyle
    var checklistAlert: ChecklistAlert? = nil
    var resolve: (() -> Void)? = nil

    var isResolvable: Bool { checklistAlert != nil || resolve != nil }
}

// MARK: - Row

private struct AlertRowView: View {
    let alert: UnifiedAlert
    let onResolveTap: () -> Void

    @Environment(\.theme) private var theme

    private var accent: Color {
        switch alert.severity {
        case .nonConforme: return theme.colorError
        case .warning: return theme.colorWarning
        case .info: return theme.colorInfo
        case .conforme: return theme.colorSuccess
        case .neutral: return theme.colorTextSecondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: alert.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(alert.module.uppercased())
                        .font(theme.typography.caption.weight(.bold))
                        .foregroundStyle(accent)
                    Spacer(minLength: 0)
                    Text(alert.date.formatted(date: .abbreviated, time: .shortened))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Text(alert.title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                if let detail = alert.detail, !detail.isEmpty {
                    Text(detail)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                if alert.isResolvable {
                    Button(action: onResolveTap) {
                        Label("Segna risolto", systemImage: "checkmark.circle.fill")
                            .font(theme.typography.caption.weight(.semibold))
                            .foregroundStyle(theme.colorSuccess)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 4)
                .padding(.vertical, 8)
        }
    }
}
