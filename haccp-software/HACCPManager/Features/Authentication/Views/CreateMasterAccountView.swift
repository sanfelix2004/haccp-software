import SwiftUI
import SwiftData

struct CreateMasterAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?
    
    let avatarColors = ["#E63946", "#F4A261", "#2A9D8F", "#264653", "#8AB17D"]
    @State private var selectedColor = "#E63946"
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 40) {
                        
                        VStack(spacing: 12) {
                            Text(AppVersionService.appName)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Configurazione Primo Avvio")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 24) {
                            // Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NOME ACCOUNT MASTER")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                TextField("Inserisci il tuo nome", text: $name)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                            }
                            
                            // Email & Phone (MASTER ONLY)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("EMAIL MASTER")
                                        .font(.caption).fontWeight(.bold).foregroundColor(.gray)
                                    TextField("email@esempio.it", text: $email)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TELEFONO")
                                        .font(.caption).fontWeight(.bold).foregroundColor(.gray)
                                    TextField("333 0000000", text: $phoneNumber)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // PIN
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PIN DI ACCESSO (4-6 CIFRE)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                SecureField("0000", text: $pin)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .onChange(of: pin) { oldValue, newValue in
                                        if newValue.count > 6 { pin = String(newValue.prefix(6)) }
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CONFERMA PIN")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                SecureField("0000", text: $confirmPin)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .onChange(of: confirmPin) { oldValue, newValue in
                                        if newValue.count > 6 { confirmPin = String(newValue.prefix(6)) }
                                    }
                            }
                            
                            // Avatar Color
                            VStack(alignment: .leading, spacing: 12) {
                                Text("COLORE AVATAR")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 16) {
                                    ForEach(avatarColors, id: \.self) { hex in
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == hex ? 3 : 0)
                                            )
                                            .onTapGesture {
                                                withAnimation(.spring()) {
                                                    selectedColor = hex
                                                }
                                            }
                                    }
                                }
                            }
                            
                            if let error = errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                            }
                            
                            Button(action: handleCreateMaster) {
                                Text("Crea Account Master")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(12)
                                    .shadow(color: .red.opacity(0.3), radius: 10, y: 5)
                            }
                            .padding(.top, 16)
                            
                        }
                        .padding(40)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .frame(maxWidth: 600)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color.black, Color(hex: "#1A0000")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
    
    private func handleCreateMaster() {
        errorMessage = nil
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Inserisci un nome valido."
            return
        }
        
        guard pin.count >= 4, pin == confirmPin else {
            errorMessage = "I PIN devono essere di almeno 4 cifre e coincidere."
            return
        }
        
        let hashedPin = PinHasher.hash(pin: pin)
        
        let newUser = LocalUser(
            name: name,
            role: .master,
            pinHash: hashedPin,
            avatarColorHex: selectedColor,
            email: email.isEmpty ? nil : email,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
        )
        
        modelContext.insert(newUser)
        do {
            try modelContext.save()
            appState.markMasterFirstAccessPending(masterId: newUser.id)
            appState.login(userId: newUser.id)
        } catch {
            errorMessage = "Errore durante il salvataggio."
        }
    }
}

