import SwiftUI

struct PinLoginView: View {
    let user: LocalUser
    var onCancel: () -> Void
    var onSuccess: () -> Void
    var isCompact: Bool = false
    
    @State private var enteredPin: String = ""
    @State private var isError: Bool = false
    @State private var biometricType: BiometricAuthManager.BiometricType = .none
    @State private var biometricErrorMessage: String?
    
    let columns = [
        GridItem(.fixed(80)),
        GridItem(.fixed(80)),
        GridItem(.fixed(80))
    ]
    
    private var showBiometrics: Bool {
        user.role == .master && biometricType != .none && SettingsStorageService.shared.security.isBiometricsEnabled
    }
    
    var body: some View {
        VStack(spacing: isCompact ? 20 : 40) {
            if !isCompact {
                headerView
            }
            
            pinDotsView
            
            if showBiometrics {
                biometricButton
            }

            if let biometricErrorMessage {
                errorMessageView(biometricErrorMessage)
            }
            
            keypadView
        }
        .padding(isCompact ? 20 : 40)
        .background(isCompact ? Color.clear : ThemeManager.shared.colorSurface)
        .cornerRadius(32)
        .frame(maxWidth: 600)
        .onAppear {
            biometricType = MasterAuthorizationService.shared.biometricType
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            ZStack {
                if let data = user.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(hex: user.avatarColorHex))
                        .frame(width: 80, height: 80)
                    
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                }
            }
            
            Text(user.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
        }
    }
    
    private var pinDotsView: some View {
        HStack(spacing: 24) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < enteredPin.count ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .scaleEffect(index < enteredPin.count ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: enteredPin.count)
            }
        }
        .padding(.vertical, 20)
        .offset(x: isError ? -10 : 0)
        .animation(isError ? .default.repeatCount(4).speed(4) : .default, value: isError)
    }
    
    private var biometricButton: some View {
        Button {
            MasterAuthorizationService.shared.authenticateBiometrically(for: .masterLogin) { success in
                if success {
                    SecurityService.shared.reportSuccessfulLogin()
                    onSuccess()
                } else {
                    biometricErrorMessage = "Biometria non riuscita. Inserisci il PIN MASTER."
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: MasterAuthorizationService.shared.biometricSymbolName)
                Text("Accedi con \(MasterAuthorizationService.shared.biometricLabel)")
            }
            .font(.headline)
            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(ThemeManager.shared.colorDivider)
            .overlay(Capsule().stroke(ThemeManager.shared.colorDivider, lineWidth: 1))
            .clipShape(Capsule())
        }
        .scaleEffect(isError ? 0.95 : 1.0)
    }
    
    private func errorMessageView(_ msg: String) -> some View {
        Text(msg)
            .font(.footnote.bold())
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var keypadView: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(1...9, id: \.self) { number in
                keypadButton(text: "\(number)", action: { addDigit("\(number)") })
        }
        
        Button(action: {
            HapticManager.shared.trigger(.medium)
            onCancel()
        }) {
            Text("Annulla")
                .font(.headline)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                .frame(width: 84, height: 84)
        }
        
        keypadButton(text: "0", action: { addDigit("0") })
        
        Button(action: {
            HapticManager.shared.trigger(.light)
            removeDigit()
        }) {
            Image(systemName: "delete.left.fill")
                .font(.title2)
                .foregroundStyle(enteredPin.isEmpty ? ThemeManager.shared.colorTextSecondary : ThemeManager.shared.colorTextPrimary)
                .frame(width: 84, height: 84)
        }
        .disabled(enteredPin.isEmpty)
    }
    .padding(.top, 20)
    .padding(.bottom, 20)
}

private func keypadButton(text: String, action: @escaping () -> Void) -> some View {
    Button(action: {
        HapticManager.shared.trigger(.light)
        action()
    }) {
        Text(text)
            .font(.system(size: 36, weight: .regular, design: .rounded))
            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            .frame(width: 84, height: 84)
            .background(ThemeManager.shared.colorDivider)
            .clipShape(Circle())
    }
    .buttonStyle(KeypadButtonStyle())
}
    
    private func addDigit(_ digit: String) {
        if enteredPin.count < 4 {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                enteredPin += digit
            }
            if enteredPin.count == 4 {
                verifyPin()
            }
        }
    }
    
    private func removeDigit() {
        if !enteredPin.isEmpty {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                enteredPin.removeLast()
            }
        }
    }
    private func verifyPin() {
        if SecurityService.shared.isLocked {
            biometricErrorMessage = "Sistema bloccato per troppi tentativi falliti."
            enteredPin = ""
            return
        }
        
        let hashed = PinHasher.hash(pin: enteredPin)
        if hashed == user.pinHash {
            SecurityService.shared.reportSuccessfulLogin()
            onSuccess()
        } else {
            SecurityService.shared.reportFailedAttempt()
            isError = true
            enteredPin = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isError = false
            }
        }
    }
}

struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
