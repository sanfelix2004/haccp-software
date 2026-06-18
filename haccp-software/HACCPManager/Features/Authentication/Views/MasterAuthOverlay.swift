import SwiftUI

struct MasterAuthOverlay<Content: View>: View {
    let master: LocalUser
    let operation: MasterAuthorizationService.Operation
    let onAuthorized: () -> Void
    let onCancel: () -> Void

    @ViewBuilder var content: Content

    @Environment(\.theme) private var theme
    @State private var appeared = false

    var body: some View {
        ZStack {
            content

            Color.black.opacity(appeared ? 0.48 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            MasterAuthorizationCard(
                user: master,
                reason: operation.localizedReason,
                onCancel: dismiss,
                onSuccess: {
                    withAnimation(theme.spring) { onAuthorized() }
                }
            )
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
        .zIndex(2000)
        .onAppear {
            withAnimation(theme.spring) { appeared = true }
        }
    }

    private func dismiss() {
        withAnimation(theme.spring) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onCancel()
        }
    }
}

// MARK: - Card compatta autorizzazione MASTER

private struct MasterAuthorizationCard: View {
    let user: LocalUser
    let reason: String
    let onCancel: () -> Void
    let onSuccess: () -> Void

    @Environment(\.theme) private var theme
    @State private var enteredPin = ""
    @State private var isError = false
    @State private var errorMessage: String?
    @State private var biometricType: BiometricAuthManager.BiometricType = .none

    private let keypadColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var showBiometrics: Bool {
        biometricType != .none && SettingsStorageService.shared.security.isBiometricsEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            pinSection
            keypad
        }
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerXL, style: .continuous)
                .fill(theme.colorSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerXL, style: .continuous)
                .stroke(theme.colorPrimary.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: theme.shadows.elevated.color, radius: 28, y: 12)
        .onAppear {
            biometricType = MasterAuthorizationService.shared.biometricType
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.colorPrimary.opacity(0.22), theme.colorPrimary.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.shield.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.colorPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Autorizzazione MASTER")
                    .font(theme.typography.subheadline.bold())
                    .foregroundStyle(theme.colorTextPrimary)
                Text(reason)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.colorTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(theme.colorDivider.opacity(0.35)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var pinSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                userAvatar(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(theme.typography.caption.bold())
                        .foregroundStyle(theme.colorTextPrimary)
                        .lineLimit(1)
                    Text("Inserisci PIN responsabile")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPin.count ? theme.colorPrimary : theme.colorDivider.opacity(0.55))
                        .frame(width: 11, height: 11)
                        .scaleEffect(index < enteredPin.count ? 1.15 : 1)
                        .animation(theme.spring, value: enteredPin.count)
                }
            }
            .padding(.vertical, 4)
            .offset(x: isError ? -8 : 0)
            .animation(isError ? .default.repeatCount(3).speed(3) : .default, value: isError)

            if showBiometrics {
                Button(action: authenticateWithBiometrics) {
                    Label(
                        MasterAuthorizationService.shared.biometricLabel,
                        systemImage: MasterAuthorizationService.shared.biometricSymbolName
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colorPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(theme.colorPrimary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colorError)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var keypad: some View {
        LazyVGrid(columns: keypadColumns, spacing: 10) {
            ForEach(1...9, id: \.self) { n in
                keypadKey("\(n)") { addDigit("\(n)") }
            }
            keypadKey("Annulla", style: .secondary) { onCancel() }
            keypadKey("0") { addDigit("0") }
            keypadKey("", systemImage: "delete.left.fill", style: .secondary) {
                removeDigit()
            }
            .disabled(enteredPin.isEmpty)
            .opacity(enteredPin.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func userAvatar(size: CGFloat) -> some View {
        if let data = user.profileImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(hex: user.avatarColorHex))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.colorTextPrimary)
                )
        }
    }

    private enum KeyStyle { case primary, secondary }

    private func keypadKey(
        _ title: String,
        systemImage: String? = nil,
        style: KeyStyle = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.trigger(.light)
            action()
        } label: {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.medium))
                } else {
                    Text(title)
                        .font(.system(size: style == .secondary ? 13 : 24, weight: style == .secondary ? .semibold : .regular, design: .rounded))
                }
            }
            .foregroundStyle(style == .secondary ? theme.colorTextSecondary : theme.colorTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(style == .secondary ? theme.colorDivider.opacity(0.22) : theme.colorSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.colorDivider.opacity(0.45), lineWidth: 0.5)
            )
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func addDigit(_ digit: String) {
        guard enteredPin.count < 4 else { return }
        errorMessage = nil
        withAnimation(theme.spring) { enteredPin += digit }
        if enteredPin.count == 4 { verifyPin() }
    }

    private func removeDigit() {
        guard !enteredPin.isEmpty else { return }
        withAnimation(theme.spring) { _ = enteredPin.removeLast() }
    }

    private func verifyPin() {
        if SecurityService.shared.isLocked {
            errorMessage = "Troppi tentativi. Riprova più tardi."
            enteredPin = ""
            return
        }
        if PinHasher.hash(pin: enteredPin) == user.pinHash {
            SecurityService.shared.reportSuccessfulLogin()
            onSuccess()
        } else {
            SecurityService.shared.reportFailedAttempt()
            isError = true
            errorMessage = "PIN non corretto"
            enteredPin = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isError = false }
        }
    }

    private func authenticateWithBiometrics() {
        MasterAuthorizationService.shared.authenticateBiometrically(for: .masterLogin) { success in
            if success {
                SecurityService.shared.reportSuccessfulLogin()
                onSuccess()
            } else {
                errorMessage = "Biometria non riuscita. Usa il PIN."
            }
        }
    }
}
