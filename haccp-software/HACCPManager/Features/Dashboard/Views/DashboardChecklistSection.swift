import SwiftUI
import Combine

struct DashboardChecklistSection: View {
    let items: [DashboardChecklistItem]
    var onOpenChecklist: () -> Void

    var body: some View {
        DashboardCardView(title: DashboardSection.checklist.rawValue) {
            if items.isEmpty {
                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessuna checklist configurata",
                        message: "Crea o configura una checklist per iniziare",
                        actionTitle: "Apri checklist"
                    ),
                    action: onOpenChecklist
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        HStack {
                            Text(item.title)
                                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                            Spacer()
                            Text(item.subtitle)
                                .foregroundColor(ThemeManager.shared.colorTextSecondary)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                        Divider().background(ThemeManager.shared.colorDivider)
                    }
                }
            }
        }
    }
}
