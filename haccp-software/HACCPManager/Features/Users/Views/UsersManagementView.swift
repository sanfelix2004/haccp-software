import SwiftUI
import SwiftData

struct UsersManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
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
    
    var filteredUsers: [LocalUser] {
        if searchText.isEmpty { return users }
        return users.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- ACTUAL LIST ---
                List {
                    Section {
                        ForEach(filteredUsers) { user in
                            UserRow(user: user)
                                .contentShape(Rectangle())
                                .listRowBackground(Color.white.opacity(0.05))
                                .onTapGesture {
                                    if user.role == .master {
                                        // Do nothing or show a haptic feedback
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    } else if currentUser?.role == .master {
                                        withAnimation(.spring()) {
                                            pendingUserToEdit = user
                                            showMasterAuthForEdit = true
                                        }
                                    }
                                }
                        }
                        .onDelete(perform: confirmDeletionPrompt)
                    } header: {
                        Text("Membri del Team")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Cerca collaboratore...")
                .foregroundStyle(.white)
                .background(Color.black)
                
                // SWIPE HINT
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                        .foregroundColor(.red)
                    Text("Scorri a sinistra per eliminare (escluso MASTER)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 16)
            }
            // --- FLOATING ACTION BUTTON (The "Ingenious" bit) ---
            if currentUser?.role == .master {
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
                                LinearGradient(colors: [.red, Color(hex: "#E63946")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(30)
                            .shadow(color: .red.opacity(0.4), radius: 20, x: 0, y: 10)
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("Gestione Staff")
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
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Image(systemName: "person.2.badge.key.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 12) {
                Text("Non hai ancora uno staff")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Inizia a costruire il tuo team per gestire i controlli HACCP del ristorante in modo granulare.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { showMasterAuthForCreate = true }) {
                Text("Crea il primo Badge")
                    .fontWeight(.bold)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
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
                        .foregroundColor(.white)
                        .font(.headline.bold())
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
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
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    }
                }
                
                if user.role == .master {
                    Text("Account protetto")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    Text(user.role.rawValue)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .fontWeight(.bold)
                        .tracking(1)
                }
            }
            
            Spacer()
            
            if user.role != .master {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding(.vertical, 8)
    }
}
