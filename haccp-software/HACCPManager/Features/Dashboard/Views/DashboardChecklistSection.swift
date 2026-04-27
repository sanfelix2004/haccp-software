import SwiftUI

struct DashboardChecklistSection: View {
    let items: [DashboardChecklistItem]
    var onOpenChecklist: () -> Void
    
    private let checklistTemplates: [String] = [
        "Checklist apertura",
        "Checklist chiusura",
        "Pulizie giornaliere",
        "Controlli operativi"
    ]

    var body: some View {
        DashboardCardView(title: DashboardSection.checklist.rawValue) {
            VStack(spacing: 10) {
                ForEach(checklistTemplates, id: \.self) { template in
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.red)
                        Text(template)
                            .foregroundColor(.white)
                        Spacer()
                        Text("Da configurare")
                            .font(.caption.bold())
                            .foregroundColor(Color.white.opacity(0.72))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

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
