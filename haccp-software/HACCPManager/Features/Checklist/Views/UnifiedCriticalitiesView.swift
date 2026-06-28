import SwiftUI

struct UnifiedCriticalitiesView: View {
    let checklistAlerts: [ChecklistAlert]
    let cleaningCriticalities: [CleaningCriticality]
    let onResolveChecklist: (ChecklistAlert, String) -> Void
    let onResolveCleaning: (CleaningCriticality, String) -> Void

    @Environment(\.theme) private var theme
    @State private var selectedChecklistAlert: ChecklistAlert?
    @State private var selectedCleaningCriticality: CleaningCriticality?
    @State private var correctiveAction = ""
    @State private var showResolveSheet = false
    @State private var validationMessage: String?

    private var restaurantId: UUID? {
        checklistAlerts.first?.restaurantId ?? cleaningCriticalities.first?.restaurantId
    }

    private var openRecords: [any HACCPCriticalityRecord] {
        guard let restaurantId else { return [] }
        return UnifiedCriticalityQuery.allOpen(
            checklistAlerts: checklistAlerts,
            cleaningCriticalities: cleaningCriticalities,
            restaurantId: restaurantId
        )
    }

    private var resolvedChecklist: [ChecklistAlert] {
        checklistAlerts.filter { !$0.isActive }.sorted { $0.createdAt > $1.createdAt }
    }

    private var resolvedCleaning: [CleaningCriticality] {
        cleaningCriticalities.filter(\.isResolved).sorted { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Registro criticità",
                    subtitle: "Pulizie e checklist in un'unica timeline per gli ispettori",
                    systemImage: "exclamationmark.triangle.fill"
                )

                if openRecords.isEmpty && resolvedChecklist.isEmpty && resolvedCleaning.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna criticità",
                        message: "Le segnalazioni compariranno quando un'attività viene marcata NON OK o Non pulito.",
                        actionTitle: nil
                    ))
                } else {
                    if !openRecords.isEmpty {
                        DashboardCardView(title: "Da risolvere", subtitle: "\(openRecords.count) aperte") {
                            LazyVStack(spacing: 10) {
                                ForEach(openRecords, id: \.id) { record in
                                    openRow(record)
                                }
                            }
                        }
                    }

                    let resolvedCount = resolvedChecklist.count + resolvedCleaning.count
                    if resolvedCount > 0 {
                        DashboardCardView(title: "Risolte", subtitle: "Storico azioni correttive") {
                            LazyVStack(spacing: 10) {
                                ForEach(resolvedChecklist.prefix(20)) { alert in
                                    resolvedChecklistRow(alert)
                                }
                                ForEach(resolvedCleaning.prefix(20)) { criticality in
                                    resolvedCleaningRow(criticality)
                                }
                            }
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
        .sheet(isPresented: $showResolveSheet) {
            resolveSheet
        }
    }

    @ViewBuilder
    private func openRow(_ record: any HACCPCriticalityRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: record.sourceModule == "cleaning" ? "sparkles" : "checklist")
                    .foregroundStyle(theme.colorError)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colorTextSecondary)
                    Text(record.message)
                        .font(theme.typography.subheadline)
                        .foregroundStyle(theme.colorTextPrimary)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer(minLength: 0)
                HACCPBadge(title: moduleLabel(record.sourceModule), style: .nonConforme, showIcon: false)
            }

            SecondaryButton(title: "Registra azione correttiva", icon: "checkmark.circle") {
                correctiveAction = ""
                validationMessage = nil
                selectedChecklistAlert = nil
                selectedCleaningCriticality = nil

                if let alert = checklistAlerts.first(where: { $0.id == record.id }) {
                    selectedChecklistAlert = alert
                } else if let criticality = cleaningCriticalities.first(where: { $0.id == record.id }) {
                    selectedCleaningCriticality = criticality
                }
                showResolveSheet = true
            }
        }
        .padding(14)
        .background(theme.colorError.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    private func resolvedChecklistRow(_ alert: ChecklistAlert) -> some View {
        resolvedRow(
            title: "Checklist",
            message: alert.message,
            action: alert.correctiveAction,
            resolvedInfo: alert.resolvedByName.map { "\($0) · \(alert.resolvedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")" }
        )
    }

    private func resolvedCleaningRow(_ criticality: CleaningCriticality) -> some View {
        resolvedRow(
            title: criticality.areaName,
            message: "\(criticality.taskName) · \(criticality.note)",
            action: criticality.correctiveAction,
            resolvedInfo: criticality.resolvedByNameSnapshot.map {
                "\($0) · \(criticality.resolvedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")"
            }
        )
    }

    private func resolvedRow(title: String, message: String, action: String?, resolvedInfo: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(theme.typography.caption.weight(.semibold)).foregroundStyle(theme.colorTextSecondary)
            Text(message).font(theme.typography.subheadline)
            if let action, !action.isEmpty {
                Label(action, systemImage: "wrench.and.screwdriver.fill")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            if let resolvedInfo {
                Text("Risolta da \(resolvedInfo)")
                    .font(theme.typography.caption2)
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    private var resolveSheet: some View {
        NavigationStack {
            Form {
                Section {
                    if let selectedChecklistAlert {
                        Text(selectedChecklistAlert.message)
                    } else if let selectedCleaningCriticality {
                        Text("\(selectedCleaningCriticality.taskName) · \(selectedCleaningCriticality.note)")
                    }
                }
                Section("Azione correttiva") {
                    TextField("Descrivi cosa è stato fatto per risolvere", text: $correctiveAction, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(theme.colorError)
                }
            }
            .navigationTitle("Risolvi criticità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { showResolveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") {
                        let text = correctiveAction.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else {
                            validationMessage = "Azione correttiva obbligatoria."
                            return
                        }
                        if let selectedChecklistAlert {
                            onResolveChecklist(selectedChecklistAlert, text)
                        } else if let selectedCleaningCriticality {
                            onResolveCleaning(selectedCleaningCriticality, text)
                        }
                        showResolveSheet = false
                    }
                }
            }
        }
    }

    private func moduleLabel(_ source: String) -> String {
        source == "cleaning" ? "Pulizia" : "Checklist"
    }
}
