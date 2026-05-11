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
    @State private var themeManager = ThemeManager.shared
    @State private var settingsStorage = SettingsStorageService.shared
    
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
        .themeProvider(themeManager)
        .preferredColorScheme(themeManager.preferredColorScheme)
        .environment(\.dynamicTypeSize, .medium)
        // Background applicato a livello root, segue lo style scelto (solid/gradient/animated...).
        .background(
            ThemedRootBackground(manager: themeManager)
                .ignoresSafeArea()
        )
        // Animazioni globali ai cambi tema/layout, regolate dal motion level.
        .animation(themeManager.motion.standard, value: settingsStorage.appearance.themePresetID)
        .animation(themeManager.motion.standard, value: settingsStorage.appearance.layoutModeRaw)
        .animation(themeManager.motion.standard, value: settingsStorage.appearance.dashboardStyleRaw)
        .animation(themeManager.motion.standard, value: settingsStorage.appearance.sidebarStyleRaw)
        .animation(themeManager.motion.standard, value: settingsStorage.appearance.backgroundStyleRaw)
        .animation(themeManager.motion.standard, value: settingsStorage.appearance.animationLevelRaw)
        .animation(themeManager.motion.standard, value: settingsStorage.appearance.followsSystemAppearance)
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
