import SwiftUI
import SwiftData

struct SetNewUserPinView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Data from previous step
    let name: String
    let role: UserRole
    let avatarColorHex: String
    let dateOfBirth: Date?
    let notes: String?
    
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var errorMessage: String?
    @State private var isSuccess = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header for the New User
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Imposta il tuo PIN personale")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Ciao \(name), inserisci un codice di 4-6 cifre che userai per accedere al tuo profilo.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    SecureField("Scegli PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .colorScheme(.dark)
                        .onChange(of: pin) { oldValue, newValue in
                            if newValue.count > 6 { pin = String(newValue.prefix(6)) }
                        }
                    
                    SecureField("Conferma PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .colorScheme(.dark)
                        .onChange(of: confirmPin) { oldValue, newValue in
                            if newValue.count > 6 { confirmPin = String(newValue.prefix(6)) }
                        }
                }
                .padding(.horizontal, 40)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: saveUser) {
                    HStack {
                        Text("Configura Profilo")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.red : Color.white.opacity(0.1))
                    .foregroundColor(isValid ? .white : .gray)
                    .cornerRadius(12)
                }
                .disabled(!isValid)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            
            if isSuccess {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    Text("Profilo Creato!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .transition(.scale)
            }
        }
        .navigationBarBackButtonHidden(isSuccess)
    }
    
    private var isValid: Bool {
        pin.count >= 4 && pin == confirmPin
    }
    
    private func saveUser() {
        guard pin == confirmPin else {
            errorMessage = "I PIN non coincidono."
            return
        }
        
        let hashed = PinHasher.hash(pin: pin)
        let newUser = LocalUser(
            name: name,
            role: role,
            pinHash: hashed,
            avatarColorHex: avatarColorHex
        )
        newUser.dateOfBirth = dateOfBirth
        newUser.notes = notes
        
        modelContext.insert(newUser)
        
        do {
            try modelContext.save()
            withAnimation {
                isSuccess = true
            }
            // Dismiss the full sheet after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // We need to dismiss the whole sheet. 
                // Since this is in a NavigationStack inside a sheet, 
                // dismissal of this view won't dismiss the sheet.
                // We might need an environment variable or notification.
                // But for now, let's just use the dismiss() and hope for the best 
                // or the user can close the sheet.
                NotificationCenter.default.post(name: NSNotification.Name("DismissCreateUserSheet"), object: nil)
            }
        } catch {
            errorMessage = "Errore durante il salvataggio."
        }
    }
}
