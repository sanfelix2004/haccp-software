import SwiftUI
import SwiftData
import Observation


struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]
    @Query private var stores: [AppDataStore]
    
    @State private var lastActivity = Date()
    
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
        .overlay {
            if appState.isLoading {
                LoadingOverlay(message: "Caricamento")
                    .zIndex(999)
            }
        }
        .onAppear {
            // Auto-selection logic for single restaurant
            if appState.isAuthenticated && restaurants.count == 1 {
                appState.activeRestaurantId = restaurants.first?.id
            }
        }
        .onChange(of: appState.isAuthenticated) { _, authenticated in
            if authenticated && restaurants.count == 1 {
                appState.activeRestaurantId = restaurants.first?.id
            }
        }
        .monitorActivity {
            lastActivity = Date()
        }
        .preferredColorScheme(ThemeManager.shared.preferredColorScheme)
        .environment(\.dynamicTypeSize, .medium)
        .animation(ThemeManager.shared.appearance.animationsEnabled ? .default : nil, value: ThemeManager.shared.appearance.theme)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && appState.isAuthenticated {
                SecurityService.shared.checkInactivity(lastActivity: lastActivity) {
                    appState.logout()
                }
            }
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
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
