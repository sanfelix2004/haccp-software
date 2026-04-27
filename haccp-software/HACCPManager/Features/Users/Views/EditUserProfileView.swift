import SwiftUI
import SwiftData

struct EditUserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var allUsers: [LocalUser]
    @Bindable var user: LocalUser
    
    var currentSessionUser: LocalUser? {
        allUsers.first { $0.id == appState.currentUserId }
    }
    
    // Using explicit states for editing to allow cancellation
    @State private var tempName: String
    @State private var tempNotes: String
    @State private var tempDateOfBirth: Date
    @State private var hasDateOfBirth: Bool
    @State private var tempRole: UserRole
    @State private var tempEmail: String
    @State private var tempPhone: String
    
    @State private var showResetPin = false
    @State private var showMasterAuth = false
    
    init(user: LocalUser) {
        self.user = user
        _tempName = State(initialValue: user.name)
        _tempNotes = State(initialValue: user.notes ?? "")
        _tempRole = State(initialValue: user.role)
        _tempEmail = State(initialValue: user.email ?? "")
        _tempPhone = State(initialValue: user.phoneNumber ?? "")
        
        if let dob = user.dateOfBirth {
            _tempDateOfBirth = State(initialValue: dob)
            _hasDateOfBirth = State(initialValue: true)
        } else {
            _tempDateOfBirth = State(initialValue: Date().addingTimeInterval(-31536000 * 20))
            _hasDateOfBirth = State(initialValue: false)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section(header: Text("Informazioni Personali")) {
                        TextField("Nome Completo", text: $tempName)
                            .foregroundColor(.white)
                        
                        if user.role == .master {
                            TextField("Email Professionale", text: $tempEmail)
                                .foregroundColor(.white)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            TextField("Telefono", text: $tempPhone)
                                .foregroundColor(.white)
                                .keyboardType(.phonePad)
                        }
                        
                        Toggle("Imposta Data di Nascita", isOn: $hasDateOfBirth)
                        
                        if hasDateOfBirth {
                            DatePicker("Data di Nascita", selection: $tempDateOfBirth, displayedComponents: .date)
                        }
                    }
                    
                    // Manage Role (Master Only, and only for others)
                    if currentSessionUser?.role == .master && user.id != appState.currentUserId {
                        Section(header: Text("Gestione Amministrativa (MASTER)")) {
                            Picker("Ruolo Collaboratore", selection: $tempRole) {
                                ForEach(UserRole.allCases.filter { $0 != .master }, id: \.self) { role in
                                    Text(role.rawValue).tag(role)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(.white)
                            
                            Button("Resetta PIN a '0000'") {
                                showResetPin = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    Section(header: Text("Note Professionali")) {
                        TextEditor(text: $tempNotes)
                            .foregroundColor(.white)
                            .frame(minHeight: 100)
                    }
                }
                .navigationTitle(user.id == appState.currentUserId ? "Mio Profilo" : "Modifica Utente")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") { 
                            if requiresMasterAuthorization {
                                showMasterAuth = true
                            } else {
                                saveChanges()
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .alert("Resetta PIN", isPresented: $showResetPin) {
                    Button("Annulla", role: .cancel) {}
                    Button("Resetta", role: .destructive) {
                        showMasterAuth = true
                    }
                } message: {
                    Text("L'azione richiederà la tua autorizzazione MASTER.")
                }
                
                if showMasterAuth, let master = allUsers.first(where: { $0.role == .master }) {
                    MasterAuthOverlay(
                        master: master,
                        operation: showResetPin ? .editUser : masterOperationForCurrentChanges,
                        onAuthorized: {
                            if showResetPin {
                                user.pinHash = PinHasher.hash(pin: "0000")
                                showResetPin = false
                            }
                            saveChanges()
                            showMasterAuth = false
                        },
                        onCancel: {
                            showMasterAuth = false
                        }
                    ) { EmptyView() }
                    .zIndex(100)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var requiresMasterAuthorization: Bool {
        currentSessionUser?.role == .master && user.id != appState.currentUserId
    }

    private var masterOperationForCurrentChanges: MasterAuthorizationService.Operation {
        tempRole != user.role ? .changeRole : .editUser
    }
    
    private func saveChanges() {
        user.name = tempName
        user.notes = tempNotes.isEmpty ? nil : tempNotes
        user.dateOfBirth = hasDateOfBirth ? tempDateOfBirth : nil
        user.role = tempRole
        
        if user.role == .master {
            user.email = tempEmail.isEmpty ? nil : tempEmail
            user.phoneNumber = tempPhone.isEmpty ? nil : tempPhone
        }
        
        try? modelContext.save()
        dismiss()
    }
}
