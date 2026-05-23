import SwiftUI
import SwiftData
import Observation


struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var blastManager: ActiveBlastChillingManager
    @EnvironmentObject private var defrostManager: ActiveDefrostManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]

    @State private var lastActivity = Date()
    @State private var themeManager = ThemeManager.shared
    @State private var settingsStorage = SettingsStorageService.shared
    @State private var didAttachSwiftDataSettings = false

    var body: some View {
        Group {
            if appState.showSplash {
                IntroSplashView()
            } else if appState.showMasterFirstAccessIntro, let masterId = appState.currentUserId {
                MasterFirstAccessIntroView {
                    appState.completeMasterFirstAccessIntro(masterId: masterId)
                }
            } else if appState.showRestaurantOnboarding || (appState.isAuthenticated && restaurants.isEmpty && users.first(where: { $0.id == appState.currentUserId })?.role == .master) {
                CreateRestaurantOnboardingView {
                    appState.showRestaurantOnboarding = false
                }
            } else if appState.isAuthenticated && restaurants.count > 1 && appState.activeRestaurantId == nil {
                PickRestaurantView()
            } else if appState.isAuthenticated {
                DashboardRootView()
            } else {
                AuthRootView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if appState.isAuthenticated && !appState.showSplash {
                ActiveKitchenTimersOverlay()
                    .zIndex(998)
            }
        }
        .overlay {
            if appState.isLoading {
                LoadingOverlay(message: "Caricamento")
                    .zIndex(999)
            }
        }
        .onAppear {
            attachSettingsStorageIfNeeded()
            if appState.isAuthenticated && restaurants.count == 1 {
                appState.activeRestaurantId = restaurants.first?.id
            }
            refreshActiveKitchenTimers()
        }
        .task {
            attachSettingsStorageIfNeeded()
        }
        .onChange(of: appState.isAuthenticated) { _, authenticated in
            if authenticated && restaurants.count == 1 {
                appState.activeRestaurantId = restaurants.first?.id
            }
            if authenticated {
                refreshActiveKitchenTimers()
            } else {
                blastManager.reset()
                defrostManager.reset()
            }
        }
        .monitorActivity {
            lastActivity = Date()
        }
        .themeProvider(themeManager)
        .tint(themeManager.colorPrimary)
        .preferredColorScheme(themeManager.preferredColorScheme)
        .background(
            ThemedRootBackground(manager: themeManager)
                .ignoresSafeArea()
        )
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && appState.isAuthenticated {
                SecurityService.shared.checkInactivity(lastActivity: lastActivity) {
                    appState.logout()
                }
                refreshActiveKitchenTimers()
            }
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            refreshActiveKitchenTimers()
        }
        .onChange(of: appState.currentUserId) { _, newUserId in
            guard let newUserId else { return }
            guard let user = users.first(where: { $0.id == newUserId }), user.role == .master else {
                appState.showMasterFirstAccessIntro = false
                return
            }
            appState.evaluateMasterFirstAccess(masterId: user.id)
        }
        .onAppear {
            guard let currentUserId = appState.currentUserId else { return }
            guard let user = users.first(where: { $0.id == currentUserId }), user.role == .master else { return }
            appState.evaluateMasterFirstAccess(masterId: user.id)
        }
    }

    private func attachSettingsStorageIfNeeded() {
        guard !didAttachSwiftDataSettings else { return }
        settingsStorage.setup(with: modelContext)
        didAttachSwiftDataSettings = true
    }

    private func refreshActiveKitchenTimers() {
        let rid = appState.activeRestaurantId
        blastManager.refresh(context: modelContext, restaurantId: rid)
        defrostManager.refresh(context: modelContext, restaurantId: rid)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(ActiveBlastChillingManager.shared)
        .environmentObject(ActiveDefrostManager.shared)
}
