import SwiftUI
import SwiftData

struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    
    // In a real app we would pass the User directly or fetch via ID
    // For simplicity we use the UUID from AppState
    @Query private var allUsers: [LocalUser]
    
    var currentUser: LocalUser? {
        allUsers.first { $0.id == appState.currentUserId }
    }
    
    @State private var showEditProfile = false
    @State private var showChangePin = false
    @State private var showVerification = false
    @State private var showMasterAuthForReset = false
    
    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()
            
            if let user = currentUser {
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Header Profile
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: user.avatarColorHex))
                                    .frame(width: 150, height: 150)
                                    .shadow(color: Color(hex: user.avatarColorHex).opacity(0.3), radius: 20)
                                
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.system(size: 60, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text(user.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(user.role.rawValue.uppercased())
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#E63946"))
                                    .tracking(2)
                                
                                if user.role == .master {
                                    VStack(spacing: 4) {
                                        if let email = user.email {
                                            Label(email, systemImage: "envelope.fill")
                                        }
                                        if let phone = user.phoneNumber {
                                            Label(phone, systemImage: "phone.fill")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.top, 40)
                        
                        // Details Card
                        VStack(spacing: 0) {
                            DetailRow(title: "Ruolo", value: user.role.rawValue)
                            Divider().background(Color.white.opacity(0.1))
                            
                            DetailRow(title: "Data di Nascita", value: user.dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "Non impostata")
                            Divider().background(Color.white.opacity(0.1))
                            
                            DetailRow(title: "Note", value: user.notes ?? "-")
                            Divider().background(Color.white.opacity(0.1))
                            
                            DetailRow(title: "Data Creazione", value: user.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(20)
                        .padding(.horizontal, 40)
                        
                        // Action Buttons
                        HStack(spacing: 20) {
                            Button(action: { showEditProfile = true }) {
                                Text("Modifica Profilo")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: { showChangePin = true }) {
                                Text("Cambia PIN")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "#E63946"))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        // Danger Zone (Only for MASTER)
                        if user.role == .master {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Zona Pericolo")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 40)
                                
                                Button(action: { showResetConfirmation = true }) {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Reset Completo Sistema")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 40)
                                
                                Text("Questa azione cancellerà TUTTI gli account (incluso il MASTER) e tutti i dati. Non può essere annullata.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 60)
                }
            } else {
                ProgressView()
            }

            if showMasterAuthForReset, let master = currentUser, master.role == .master {
                MasterAuthOverlay(
                    master: master,
                    operation: .resetDatabase,
                    onAuthorized: {
                        showMasterAuthForReset = false
                        resetEntireSystem()
                    },
                    onCancel: {
                        showMasterAuthForReset = false
                    }
                ) { EmptyView() }
                .zIndex(50)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Il Mio Profilo")
        .sheet(isPresented: $showEditProfile) {
            if let user = currentUser {
                EditUserProfileView(user: user)
            }
        }
        .sheet(isPresented: $showChangePin) {
            ChangePinView(user: currentUser!)
        }
        .alert("CONFERMA RESET TOTALE", isPresented: $showResetConfirmation) {
            Button("Annulla", role: .cancel) {}
            Button("PROCEDI AL RESET", role: .destructive) {
                showMasterAuthForReset = true
            }
        } message: {
            Text("Sei assolutamente sicuro? Tutti i dati verranno eliminati permanentemente.")
        }
    }
    
    @State private var showResetConfirmation = false
    
    private func resetEntireSystem() {
        // Delete all users
        for user in allUsers {
            modelContext.delete(user)
        }
        try? modelContext.save()
        
        // Final logout
        appState.logout()
    }
}

// Reusable Row Component
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
                .font(.subheadline)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
    }
}
