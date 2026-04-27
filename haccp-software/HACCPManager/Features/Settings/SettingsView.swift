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
            Color(hex: "#0A0A0A").ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Impostazioni")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Configura e personalizza il tuo sistema gestionale HACCP certificato.")
                            .font(.title3)
                            .foregroundColor(.gray)
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
                            Text("Versione 1.0.0 (Build 2026.04)")
                                .font(.caption)
                            Text("© 2026 Romanazzi IT Solutions. All rights reserved.")
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.15))
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
                    Color.black.opacity(0.85).ignoresSafeArea()
                        .onTapGesture { viewModel.selectedSection = nil }
                    
                    SettingsDetailContainer(section: section, currentUser: currentUser) {
                        viewModel.selectedSection = nil
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .zIndex(100)
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
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 54, height: 54)
                    Image(systemName: section.icon)
                        .font(.title)
                        .foregroundColor(.red)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.rawValue)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text(section.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(24)
            .background(Color.white.opacity(0.03))
            
            Divider().background(Color.white.opacity(0.1))
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    detailView(for: section)
                }
                .padding(32)
            }
            .background(Color(hex: "#0F0F0F"))
        }
        .frame(maxWidth: 750)
        .frame(maxHeight: 900)
        .background(Color(hex: "#0F0F0F"))
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.6), radius: 40)
        .padding(40)
    }
    
    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .profile: ProfileSettingsView(user: currentUser)
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
