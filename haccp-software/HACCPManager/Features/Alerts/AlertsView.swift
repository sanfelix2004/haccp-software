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
    @Query private var traceabilityRecords: [TraceabilityRecord]
    @Query private var goodsReceipts: [GoodsReceivingRecord]
    @Query private var productionLabels: [ProductionLabelRecord]
    @Query private var users: [LocalUser]

    @State private var alertToResolve: UnifiedAlert?
    @State private var checklistAlertToResolve: ChecklistAlert?
    @State private var checklistCorrectiveAction = ""
    @State private var checklistResolveError: String?

    private let checklistService = ChecklistService()

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var soonThresholdDays: Int {
        SettingsStorageService.shared.haccp.productExpiryThreshold
    }

    // MARK: - Unified model

    private var allAlerts: [UnifiedAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return HACCPUnifiedAlertsBuilder.build(
            restaurantId: rid,
            temperatureAlerts: temperatureAlerts,
            cleaningCriticalities: cleaningCriticalities,
            defrostCriticalities: defrostCriticalities,
            oilAlerts: oilAlerts,
            checklistAlerts: checklistAlerts,
            traceabilityRecords: traceabilityRecords,
            goodsReceipts: goodsReceipts,
            productionLabels: productionLabels,
            soonThresholdDays: soonThresholdDays,
            resolveTemperature: resolveTemperatureAlert,
            resolveCleaning: resolveCriticality,
            resolveDefrost: resolveDefrostCriticality,
            resolveOil: resolveOilAlert,
            resolveTraceabilityNC: resolveTraceabilityNC,
            resolveGoodsNC: resolveGoodsNC
        ).map { candidate in
            UnifiedAlert(
                id: candidate.id,
                module: candidate.module,
                icon: candidate.icon,
                title: candidate.title,
                detail: candidate.detail,
                date: candidate.date,
                severity: candidate.severity,
                navigationTarget: candidate.navigationTarget,
                checklistAlert: candidate.checklistAlert,
                resolve: candidate.resolve
            )
        }
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
                ModuleScreenHeader(
                    title: "Avvisi",
                    subtitle: "Criticità da temperature, pulizie, scadenze, tracciabilità, ricezione, etichette e checklist",
                    systemImage: "bell.badge.fill",
                    help: ModuleHelpLibrary.sidebar(.alerts)
                )

                statsRow

                if allAlerts.isEmpty {
                    DashboardCardView(title: "Avvisi") {
                        DashboardEmptyStateView(state: .init(
                            title: "Tutto sotto controllo",
                            message: "Nessun avviso attivo. Compariranno qui scadenze, NC, temperature, pulizie, etichette e checklist.",
                            actionTitle: nil
                        ))
                    }
                } else {
                    DashboardCardView(title: "Da gestire", subtitle: "\(allAlerts.count) avvisi attivi") {
                        LazyVStack(spacing: 10) {
                            ForEach(allAlerts) { alert in
                                AlertRowView(alert: alert) {
                                    openModule(for: alert)
                                } onResolveTap: {
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

    private func openModule(for alert: UnifiedAlert) {
        guard let target = alert.navigationTarget else { return }
        HapticManager.shared.selection()
        appState.pendingSidebarNavigation = target
    }

    private func resolveGoodsNC(_ receipt: GoodsReceivingRecord) {
        guard let user = currentUser else { return }
        receipt.nonComplianceResolvedAt = Date()
        receipt.nonComplianceResolvedByNameSnapshot = user.name
        if let record = traceabilityRecords.first(where: { $0.goodsReceiptId == receipt.id }) {
            record.nonComplianceResolvedAt = receipt.nonComplianceResolvedAt
            record.nonComplianceResolvedByNameSnapshot = user.name
        }
        try? modelContext.save()
    }

    private func resolveTraceabilityNC(_ record: TraceabilityRecord) {
        guard let user = currentUser else { return }
        record.nonComplianceResolvedAt = Date()
        record.nonComplianceResolvedByNameSnapshot = user.name
        if let receiptId = record.goodsReceiptId,
           let receipt = goodsReceipts.first(where: { $0.id == receiptId }) {
            receipt.nonComplianceResolvedAt = record.nonComplianceResolvedAt
            receipt.nonComplianceResolvedByNameSnapshot = user.name
        }
        try? modelContext.save()
    }

    private func resolveDefrostCriticality(_ criticality: DefrostCriticality) {
        guard let user = currentUser else { return }
        try? DefrostService().resolveCriticality(criticality, user: user, modelContext: modelContext)
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
    var navigationTarget: SidebarItem? = nil
    var checklistAlert: ChecklistAlert? = nil
    var resolve: (() -> Void)? = nil

    var isResolvable: Bool { checklistAlert != nil || resolve != nil }
}

// MARK: - Row

private struct AlertRowView: View {
    let alert: UnifiedAlert
    let onOpenTap: () -> Void
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
            rowLeading
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
        .contentShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .onTapGesture(perform: onOpenTap)
    }

    private var rowLeading: some View {
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
                if alert.navigationTarget != nil {
                    Text("Tocca per aprire il modulo")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
        }
    }
}
