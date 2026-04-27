import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]

    @StateObject private var viewModel: DashboardViewModel
    @State private var appeared = false
    
    init() {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(provider: DashboardDataProvider()))
    }

    var activeRestaurant: Restaurant? {
        if let activeId = stores.first?.activeRestaurantId {
            return restaurants.first { $0.id == activeId }
        }
        return restaurants.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DashboardHeaderView(
                    user: currentUser,
                    restaurant: activeRestaurant,
                    dateTimeText: viewModel.formattedDateTime,
                    systemStateMessage: "Sistema pronto per \(activeRestaurant?.name ?? "il tuo ristorante")"
                )
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(ThemeManager.shared.spring, value: appeared)

                DashboardCardView(title: "Home Dashboard") {
                    Text("Seleziona una sezione dal menu laterale per accedere a Moduli HACCP, Checklist, Grafici, Alert e Attivita recenti.")
                        .font(.headline)
                        .foregroundColor(Color.white.opacity(0.86))
                        .multilineTextAlignment(.leading)
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(ThemeManager.shared.spring.delay(0.1), value: appeared)

                DashboardCardView(title: "Stato generale") {
                    Text("Nessun dato disponibile")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Le statistiche appariranno qui quando saranno disponibili dati reali.")
                        .foregroundColor(Color.white.opacity(0.72))
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(ThemeManager.shared.spring.delay(0.2), value: appeared)
            }
            .padding(24)
        }
        .background(ThemeManager.shared.background.ignoresSafeArea())
        .navigationTitle("Dashboard")
        .onAppear {
            withAnimation {
                appeared = true
            }
            viewModel.reload()
        }
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }
}
