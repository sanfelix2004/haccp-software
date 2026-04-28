import SwiftUI

struct HACCPModulesView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let modules: [DashboardModule] = [
        .init(name: "Temperature", description: "Monitoraggio e registrazioni termiche", icon: "thermometer.medium", state: .open, isEnabled: true),
        .init(name: "Checklist", description: "Procedure operative giornaliere", icon: "checklist", state: .open, isEnabled: true),
        .init(name: "Pulizie", description: "Piani e conferme di sanificazione", icon: "sparkles", state: .configure, isEnabled: false),
        .init(name: "Prodotti", description: "Lotti, scadenze e tracciabilita", icon: "archivebox.fill", state: .configure, isEnabled: false),
        .init(name: "Etichette", description: "Gestione etichette di preparazione", icon: "tag.fill", state: .configure, isEnabled: false),
        .init(name: "Scongelamento", description: "Controllo procedure di scongelamento", icon: "snowflake", state: .configure, isEnabled: false),
        .init(name: "Abbattimento", description: "Flussi e registrazioni abbattitore", icon: "wind.snow", state: .configure, isEnabled: false),
        .init(name: "Report", description: "Esportazioni e storico conformita", icon: "doc.text.fill", state: .open, isEnabled: true)
    ]

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Moduli HACCP") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(modules) { module in
                        moduleCard(module)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Moduli HACCP")
    }

    @ViewBuilder
    private func moduleCard(_ module: DashboardModule) -> some View {
        if module.name == "Temperature" {
            NavigationLink {
                TemperatureRootView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else {
            cardBody(module)
        }
    }

    private func cardBody(_ module: DashboardModule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: module.icon)
                .font(.title2)
                .foregroundColor(.red)
            Text(module.name)
                .font(.headline)
                .foregroundColor(.white)
            Text(module.description)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.72))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(14)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
