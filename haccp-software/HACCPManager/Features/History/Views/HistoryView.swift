import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var loader = ModuleStoreRegistry.shared.history

    var body: some View {
        Group {
            if loader.isLoading && loader.entries.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Caricamento storico…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HistoryDashboardView(entries: loader.entries)
            }
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            loader.reload(context: modelContext, restaurantId: appState.activeRestaurantId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitchenProcessRecordsDidChange)) { _ in
            loader.reload(
                context: modelContext,
                restaurantId: appState.activeRestaurantId,
                force: true
            )
        }
    }
}
