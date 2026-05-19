import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [LocalUser]
    
    @State private var viewModel = SettingsViewModel()
    private var storage = SettingsStorageService.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }
    
    var masterUser: LocalUser? {
        users.first { $0.role == .master }
    }
    
    var body: some View {
        ZStack {
            ThemeManager.shared.colorBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Impostazioni")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(ThemeManager.shared.colorTextPrimary)
                        
                        Text("Configura e personalizza il tuo sistema gestionale HACCP certificato.")
                            .font(.title3)
                            .foregroundColor(ThemeManager.shared.colorTextSecondary)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 40)
                    
                    // Grid of Sections
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(SettingsSection.allCases) { section in
                            SettingsCardView(section: section) {
                                viewModel.sectionTapped(section, isMaster: currentUser?.role == .master)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // App Version Footer
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("HACCP Manager Premium Edition")
                                .font(.headline)
                            Text(AppVersionService.currentVersion)
                                .font(.caption)
                            Text("© 2026 Romanazzi IT Solutions. All rights reserved.")
                                .font(.caption2)
                        }
                        .foregroundColor(ThemeManager.shared.colorTextSecondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                }
            }
            
            // Detail Navigation (Using a custom modal-like overlay for premium feel on iPad)
            if let section = viewModel.selectedSection {
                ZStack {
                    ThemeManager.shared.colorBackground.opacity(0.92)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.selectedSection = nil }

                    SettingsDetailContainer(section: section, currentUser: currentUser) {
                        viewModel.selectedSection = nil
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .zIndex(100)
                .allowsHitTesting(true)
            }
        }
        .onAppear {
            storage.setup(with: modelContext)
        }
        .fullScreenCover(isPresented: $viewModel.showMasterAuth) {
            if let master = masterUser {
                MasterAuthOverlay(
                    master: master,
                    operation: .accessSettings,
                    onAuthorized: {
                        viewModel.handleMasterAuthorized()
                    },
                    onCancel: {
                        viewModel.showMasterAuth = false
                    }
                ) { EmptyView() }
            }
        }
        .navigationTitle("Impostazioni")
        .navigationBarHidden(true) // We use our custom header
    }
}

struct SettingsDetailContainer: View {
    let section: SettingsSection
    let currentUser: LocalUser?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(ThemeManager.shared.colorPrimary.opacity(0.2))
                        .frame(width: 54, height: 54)
                    Image(systemName: section.icon)
                        .font(.title)
                        .foregroundColor(ThemeManager.shared.colorPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.rawValue)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(ThemeManager.shared.colorTextPrimary)
                    Text(section.description)
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.colorTextSecondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(ThemeManager.shared.colorTextSecondary.opacity(0.6))
                }
            }
            .padding(24)
            .background(ThemeManager.shared.colorSurfaceElevated)
            
            Divider().background(ThemeManager.shared.colorDivider)
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    detailView(for: section)
                }
                .padding(32)
            }
            .background(ThemeManager.shared.colorSurface)
        }
        .frame(maxWidth: 750)
        .frame(maxHeight: 900)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(32)
        .shadow(color: ThemeManager.shared.shadows.elevated.color, radius: 40)
        .padding(40)
    }
    
    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .profile: ProfileSettingsView(user: currentUser)
        case .appearance: AppearanceSettingsView()
        case .security: SecuritySettingsView()
        case .restaurant: RestaurantSettingsView()
        case .haccp: HACCPSettingsView()
        case .notifications: NotificationSettingsView()
        case .data: DataBackupSettingsView()
        case .printer: LabelPrinterSettingsView()
        case .info: AppInfoSettingsView()
        }
    }
}
