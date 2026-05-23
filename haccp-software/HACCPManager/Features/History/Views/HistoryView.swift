import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loader = HistoryLoaderViewModel()

    var body: some View {
        Group {
            if loader.isLoading && loader.entries.isEmpty {
                ProgressView("Caricamento storico…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HistoryDashboardView(entries: loader.entries)
            }
        }
        .task(id: appState.activeRestaurantId) {
            loader.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitchenProcessRecordsDidChange)) { _ in
            loader.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
    }
}
