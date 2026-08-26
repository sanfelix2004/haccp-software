import SwiftUI
import SwiftData

/// Tracciabilità cucina: la fotocamera è la schermata. Nessun hub intermedio.
struct TraceabilityView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var session: RestaurantSessionContext
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                DashboardEmptyStateView(state: .init(
                    title: "Seleziona un ristorante",
                    message: "La tracciabilità è legata al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(theme.spacing.screenPadding)
            } else if let restaurantId = appState.activeRestaurantId, let user = session.currentUser {
                TraceabilityLotCaptureFlowView(
                    restaurantId: restaurantId,
                    user: user,
                    restaurantName: session.activeRestaurant?.name
                )
            } else {
                ProgressView("Preparazione fotocamera…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
