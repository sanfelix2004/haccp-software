import SwiftUI

struct EmailVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    let user: LocalUser
    var onVerified: () -> Void
    
    @State private var pin: String = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var isError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Verifica Email")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Per procedere con operazioni sensibili, inserisci il codice di sicurezza.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Verifica Identità")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Per verificare l'email, inserisci il tuo PIN attuale.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 24) {
                    SecureField("Inserisci PIN", text: $pin)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: pin) { newValue in
                            if newValue.count > 4 {
                                pin = String(newValue.prefix(4))
                            }
                        }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: verifyPin) {
                        HStack {
                            if isVerifying {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text("Conferma")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pin.count == 4 ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(pin.count != 4 || isVerifying)
                }
                .padding(.horizontal, 40)
                .offset(x: isError ? -10 : 0)
                .animation(isError ? Animation.default.repeatCount(3).speed(3) : .default, value: isError)
                
                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func verifyPin() {
        isVerifying = true
        errorMessage = nil
        
        // Instant check
        let hashedInput = PinHasher.hash(pin: pin)
        
        if hashedInput == user.pinHash {
            onVerified()
        } else {
            isVerifying = false
            errorMessage = "PIN non corretto."
            isError = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isError = false
            }
        }
    }
}
