import SwiftUI
import SwiftData

struct UsersManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme
    @Query(sort: \LocalUser.name) private var users: [LocalUser]
    
    @State private var showCreateUser = false
    @State private var selectedUser: LocalUser?
    @State private var searchText = ""
    @State private var userToDelete: IndexSet?
    @State private var pendingUserToEdit: LocalUser?
    @State private var showMasterAuthForDelete = false
    @State private var showMasterAuthForCreate = false
    @State private var showMasterAuthForEdit = false
    @State private var showDeleteAlert = false
    
    var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var canManageUsers: Bool {
        currentUser.permissions.can(.manageUsers)
    }
    
    var filteredUsers: [LocalUser] {
        if searchText.isEmpty { return users }
        return users.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            theme.colorBackground.ignoresSafeArea()
            
            if filteredUsers.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    List {
                        Section {
                            ForEach(filteredUsers) { user in
                                UserRow(user: user)
                                    .contentShape(Rectangle())
                                    .listRowBackground(theme.colorSurface)
                                    .onTapGesture {
                                        if user.role == .master {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        } else if canManageUsers {
                                            withAnimation(.spring()) {
                                                pendingUserToEdit = user
                                                showMasterAuthForEdit = true
                                            }
                                        }
                                    }
                            }
                            .onDelete(perform: canManageUsers ? confirmDeletionPrompt : { _ in })
                        } header: {
                            Text("Membri del team")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Cerca collaboratore…")
                    .foregroundStyle(theme.colorTextPrimary)
                    .background(theme.colorBackground)

                    if canManageUsers {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.draw.fill")
                                .foregroundStyle(theme.colorPrimary)
                            Text("Scorri a sinistra per eliminare (escluso il responsabile)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            // --- FLOATING ACTION BUTTON (The "Ingenious" bit) ---
            if canManageUsers {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showMasterAuthForCreate = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.title2)
                                Text("Aggiungi Collaboratore")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [theme.colorPrimary, theme.colorPrimary.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(theme.colorTextOnPrimary)
                            .cornerRadius(30)
                            .shadow(color: theme.colorPrimary.opacity(0.35), radius: 20, x: 0, y: 10)
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("Collaboratori")
        .moduleHelpToolbar(ModuleHelpLibrary.sidebar(.users))
        .alert("Conferma Eliminazione", isPresented: $showDeleteAlert) {
            Button("Annulla", role: .cancel) { userToDelete = nil }
            Button("Elimina", role: .destructive) {
                showMasterAuthForDelete = true
            }
        } message: {
            Text("Sei sicuro di voler eliminare questo collaboratore? L'azione è irreversibile e richiederà la tua autorizzazione MASTER.")
        }
        .sheet(isPresented: $showCreateUser) {
            CreateUserView()
        }
        .sheet(item: $selectedUser) { user in
            EditUserProfileView(user: user)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissCreateUserSheet"))) { _ in
            showCreateUser = false
        }
        .fullScreenCover(isPresented: $showMasterAuthForDelete) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .deleteUser,
                    onAuthorized: {
                        if let offsets = userToDelete {
                            performActualDeletion(offsets: offsets)
                        }
                        showMasterAuthForDelete = false
                        userToDelete = nil
                    },
                    onCancel: {
                        showMasterAuthForDelete = false
                        userToDelete = nil
                    }
                ) { EmptyView() }
            }
        }
        .fullScreenCover(isPresented: $showMasterAuthForCreate) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .createUser,
                    onAuthorized: {
                        showMasterAuthForCreate = false
                        showCreateUser = true
                    },
                    onCancel: {
                        showMasterAuthForCreate = false
                    }
                ) { EmptyView() }
            }
        }
        .fullScreenCover(isPresented: $showMasterAuthForEdit) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .editUser,
                    onAuthorized: {
                        selectedUser = pendingUserToEdit
                        pendingUserToEdit = nil
                        showMasterAuthForEdit = false
                    },
                    onCancel: {
                        pendingUserToEdit = nil
                        showMasterAuthForEdit = false
                    }
                ) { EmptyView() }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.colorPrimary.opacity(0.1))
                    .frame(width: 180, height: 180)

                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(theme.colorPrimary)
            }

            VStack(spacing: 12) {
                Text(searchText.isEmpty ? "Nessun collaboratore" : "Nessun risultato")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.colorTextPrimary)

                Text(searchText.isEmpty
                     ? "Aggiungi i collaboratori per gestire insieme i controlli HACCP del ristorante."
                     : "Nessun collaboratore corrisponde alla ricerca.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.colorTextSecondary)
                    .padding(.horizontal, 40)
            }

            if searchText.isEmpty, canManageUsers {
                PrimaryButton(title: "Aggiungi collaboratore", icon: "person.badge.plus") {
                    showMasterAuthForCreate = true
                }
                .frame(maxWidth: 280)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func confirmDeletionPrompt(offsets: IndexSet) {
        // Prepare for auth
        self.userToDelete = offsets
        self.showDeleteAlert = true
    }
    
    private func performActualDeletion(offsets: IndexSet) {
        for index in offsets {
            let user = filteredUsers[index]
            if user.id == appState.currentUserId || user.role == .master {
                continue
            }
            modelContext.delete(user)
        }
        try? modelContext.save()
    }
}

struct UserRow: View {
    let user: LocalUser
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                if let data = user.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(hex: user.avatarColorHex))
                        .frame(width: 48, height: 48)
                    
                    Text(String(user.name.prefix(1)).uppercased())
                        .foregroundStyle(theme.colorTextOnPrimary)
                        .font(.headline.bold())
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                    
                    if user.role == .master {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8))
                            Text("MASTER")
                                .font(.system(size: 10, weight: .black))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#D4AF37")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .foregroundStyle(theme.isDark ? theme.colorTextPrimary : Color(hex: "#1A1D21"))
                        .clipShape(Capsule())
                    }
                }
                
                if user.role == .master {
                    Text("Account protetto")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.colorTextSecondary)
                        .italic()
                } else {
                    Text(user.role.displayName)
                        .font(.caption)
                        .foregroundStyle(theme.colorPrimary)
                        .fontWeight(.bold)
                }
            }
            
            Spacer()
            
            if user.role != .master {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.colorTextSecondary.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
    }
}
