import SwiftUI

struct ChecklistTemplatesView: View {
    let templates: [ChecklistTemplate]
    let canManage: Bool
    let canExecute: Bool
    let onCreate: () -> Void
    let onStartRun: (ChecklistTemplate) -> Void
    let onEdit: (ChecklistTemplate) -> Void
    let onDelete: (ChecklistTemplate) -> Void
    let currentRole: UserRole?

    @Environment(\.theme) private var theme
    @State private var categoryFilter: ChecklistCategory?
    @State private var frequencyFilter: ChecklistFrequency?
    @State private var searchText = ""

    private var filtered: [ChecklistTemplate] {
        templates
            .filter { template in
                guard let categoryFilter else { return true }
                return template.category == categoryFilter
            }
            .filter { template in
                guard let frequencyFilter else { return true }
                return template.frequency == frequencyFilter
            }
            .filter { template in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return template.title.localizedCaseInsensitiveContains(query)
                    || template.checklistDescription.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Modelli checklist",
                    subtitle: "Procedure ripetibili per apertura, pulizie, HACCP",
                    systemImage: "doc.text.fill"
                )

                if canManage {
                    PrimaryButton(title: "Nuovo modello", icon: "plus.circle.fill", action: onCreate)
                }

                DashboardCardView(title: "Filtra modelli", subtitle: "\(filtered.count) risultati") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(theme.colorTextSecondary)
                            TextField("Cerca modello…", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(12)
                        .background(theme.colorSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))

                        ChecklistFilterBar(
                            categoryFilter: $categoryFilter,
                            frequencyFilter: $frequencyFilter
                        )
                    }
                }

                if filtered.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessun modello",
                        message: "Crea un modello checklist per standardizzare i controlli in cucina.",
                        actionTitle: canManage ? "Nuovo modello" : nil
                    )) {
                        if canManage { onCreate() }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { template in
                            ChecklistTemplateCard(
                                template: template,
                                canExecute: canExecute && template.isActive,
                                canManage: canManage,
                                canDelete: canManage,
                                onStart: { onStartRun(template) },
                                onEdit: { onEdit(template) },
                                onDelete: { onDelete(template) }
                            )
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
    }
}
