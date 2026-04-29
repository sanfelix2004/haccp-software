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
                                .foregroundColor(.white)
                            Spacer()
                            Text(item.subtitle)
                                .foregroundColor(Color.white.opacity(0.72))
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
        }
    }
}
