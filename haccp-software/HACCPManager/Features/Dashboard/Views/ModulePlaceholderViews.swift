import SwiftUI

struct ExpiryControlView: View {
    var body: some View {
        ScrollView {
            DashboardCardView(title: "Controllo scadenze") {
                professionalPlaceholder
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Controllo scadenze")
    }

    private var professionalPlaceholder: some View {
        DashboardEmptyStateView(state: .init(
            title: "Modulo in preparazione",
            message: "Qui potrai monitorare scadenze e allineamento con la tracciabilità. La struttura è già prevista nel menu e nei report.",
            actionTitle: nil
        ))
    }
}

struct ModuleTimerView: View {
    var body: some View {
        ScrollView {
            DashboardCardView(title: "Module Timer") {
                DashboardEmptyStateView(state: .init(
                    title: "Modulo in preparazione",
                    message: "Timer e promemoria operativi saranno disponibili in una prossima versione.",
                    actionTitle: nil
                ))
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Module Timer")
    }
}
