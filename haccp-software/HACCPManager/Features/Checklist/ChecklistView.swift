import SwiftUI

struct ChecklistView: View {
    var body: some View {
        ScrollView {
            DashboardCardView(title: "Checklist") {
                VStack(spacing: 10) {
                    checklistTemplateRow("Checklist apertura")
                    checklistTemplateRow("Checklist chiusura")
                    checklistTemplateRow("Pulizie giornaliere")
                    checklistTemplateRow("Controlli operativi")
                }

                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessuna checklist configurata",
                        message: "Crea o configura una checklist per iniziare",
                        actionTitle: "Apri checklist"
                    )
                )
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Checklist")
    }

    private func checklistTemplateRow(_ title: String) -> some View {
        HStack {
            Image(systemName: "checklist")
                .foregroundColor(.red)
            Text(title)
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
