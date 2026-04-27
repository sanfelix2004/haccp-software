import SwiftUI
import SwiftData

struct ChangePinView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: LocalUser
    
    @State private var oldPin: String = ""
    @State private var newPin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?
    @State private var isError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    VStack(spacing: 24) {
                        // Old PIN
                        VStack(alignment: .leading, spacing: 8) {
                            Text("VECCHIO PIN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            
                            SecureField("****", text: $oldPin)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .onChange(of: oldPin) { newValue in
                                    if newValue.count > 4 { oldPin = String(newValue.prefix(4)) }
                                }
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // New PIN
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NUOVO PIN (4 CIFRE)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            
                            SecureField("****", text: $newPin)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .onChange(of: newPin) { newValue in
                                    if newValue.count > 4 { newPin = String(newValue.prefix(4)) }
                                }
                        }
                        
                        // Confirm New PIN
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONFERMA NUOVO PIN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            
                            SecureField("****", text: $confirmPin)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .onChange(of: confirmPin) { newValue in
                                    if newValue.count > 4 { confirmPin = String(newValue.prefix(4)) }
                                }
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.top, 8)
                        }
                        
                        Button(action: saveNewPin) {
                            Text("Cambia PIN")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid ? Color.red : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!isFormValid)
                        .padding(.top, 20)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(24)
                }
                .padding(24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Modifica PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var isFormValid: Bool {
        oldPin.count == 4 && newPin.count == 4 && confirmPin.count == 4 && newPin == confirmPin
    }
    
    private func saveNewPin() {
        errorMessage = nil
        
        let hashedOld = PinHasher.hash(pin: oldPin)
        
        if hashedOld != user.pinHash {
            errorMessage = "Il vecchio PIN non è corretto."
            return
        }
        
        if newPin != confirmPin {
            errorMessage = "I nuovi PIN non coincidono."
            return
        }
        
        let hashedNew = PinHasher.hash(pin: newPin)
        user.pinHash = hashedNew
        try? modelContext.save()
        dismiss()
    }
}
