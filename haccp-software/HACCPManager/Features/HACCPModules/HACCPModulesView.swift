import SwiftUI

struct HACCPModulesView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let modules: [DashboardModule] = [
        .init(name: "Programmazione", description: "Attivita periodiche e promemoria", icon: "calendar.badge.clock", state: .open, isEnabled: true),
        .init(name: "Tracciabilita", description: "Prodotti, lotti e fornitori", icon: "archivebox.fill", state: .open, isEnabled: true),
        .init(name: "Frigoriferi", description: "Controllo temperature frigo/freezer", icon: "thermometer.medium", state: .open, isEnabled: true),
        .init(name: "Controllo pulizia", description: "Piani pulizia e firme operatore", icon: "sparkles", state: .open, isEnabled: true),
        .init(name: "Abbattimento", description: "Abbattimento in negativo", icon: "wind.snow", state: .open, isEnabled: true),
        .init(name: "Decongelamento", description: "Procedure di decongelamento", icon: "snowflake", state: .open, isEnabled: true),
        .init(name: "Controllo olio", description: "Stato olio frittura e azioni", icon: "drop.fill", state: .open, isEnabled: true),
        .init(name: "Etichette", description: "Etichette di produzione", icon: "tag.fill", state: .open, isEnabled: true),
        .init(name: "Ricezione merci", description: "Controllo conformita in ingresso", icon: "shippingbox.fill", state: .open, isEnabled: true),
        .init(name: "Documenti", description: "Cartelle e documenti HACCP", icon: "folder.fill", state: .open, isEnabled: true),
        .init(name: "Storia", description: "Archivio registrazioni centralizzato", icon: "clock.arrow.circlepath", state: .open, isEnabled: true)
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
        if module.name == "Programmazione" {
            NavigationLink {
                SchedulingView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Tracciabilita" {
            NavigationLink {
                TraceabilityView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Frigoriferi" {
            NavigationLink {
                FridgesView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Controllo pulizia" {
            NavigationLink {
                CleaningControlView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Abbattimento" {
            NavigationLink {
                BlastChillingView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Decongelamento" {
            NavigationLink {
                DefrostView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Controllo olio" {
            NavigationLink {
                OilControlView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Etichette" {
            NavigationLink {
                ProductionLabelsView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Ricezione merci" {
            NavigationLink {
                GoodsReceivingView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Documenti" {
            NavigationLink {
                DocumentsView()
            } label: {
                cardBody(module)
            }
            .buttonStyle(.plain)
        } else if module.name == "Storia" {
            NavigationLink {
                HistoryView()
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
