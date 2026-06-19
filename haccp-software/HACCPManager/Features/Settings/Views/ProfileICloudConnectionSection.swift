//
//  ProfileICloudConnectionSection.swift
//  Collegamento iCloud dal profilo utente per la sync documenti.
//

import SwiftUI
import SwiftData

struct ProfileICloudConnectionSection: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @Query private var restaurants: [Restaurant]
    @Query private var documentItems: [DocumentItem]

    @ObservedObject private var iCloudSync = ICloudDocumentSyncService.shared

    @AppStorage(DocumentsUserSettings.iCloudPDFSyncEnabledKey) private var iCloudPDFSyncEnabled = true

    @State private var contactEmail = ""
    @State private var emailValidationMessage: String?
    @State private var isVerifying = false

    private var activeRestaurant: Restaurant? {
        guard let rid = appState.activeRestaurantId else { return nil }
        return restaurants.first { $0.id == rid }
    }

    private var hasICloudAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var isConnected: Bool {
        iCloudSync.isUbiquityContainerAvailable
    }

    private var statusTitle: String {
        if isConnected { return "Collegato a iCloud Drive" }
        if !hasICloudAccount { return "Account iCloud non attivo" }
        return "In attesa di iCloud Drive"
    }

    private var statusColor: Color {
        if isConnected && iCloudPDFSyncEnabled { return .green }
        if isConnected { return .orange }
        return .red
    }

    private var statusIcon: String {
        if isConnected { return "icloud.fill" }
        if !hasICloudAccount { return "icloud.slash" }
        return "exclamationmark.icloud"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: statusIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("iCLOUD DOCUMENTI")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        .tracking(1)
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    Text(connectionHint)
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if let name = activeRestaurant?.name {
                Label(name, systemImage: "building.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }

            Toggle(isOn: $iCloudPDFSyncEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sincronizza PDF su iCloud")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    Text("Abilita la copia automatica dei registri HACCP nella schermata Documenti.")
                        .font(.caption2)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                }
            }
            .tint(.red)
            .disabled(!isConnected)

            emailField

            HStack(spacing: 12) {
                Button(action: openSystemSettings) {
                    Label("Impostazioni iCloud", systemImage: "gear")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ThemeManager.shared.colorDivider)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: { Task { await verifyConnection() } }) {
                    Group {
                        if isVerifying {
                            ProgressView()
                        } else {
                            Label("Verifica", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isVerifying)
            }

            if !iCloudSync.connectionExplanation.isEmpty {
                Text(iCloudSync.connectionExplanation)
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Dopo il collegamento, apri Documenti e usa «Sincronizza ora» per copiare l'archivio PDF su iCloud Drive.")
                .font(.caption2)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(20)
        .onAppear {
            loadContactEmail()
            iCloudSync.refreshConnectionDiagnostics()
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            loadContactEmail()
        }
        .onChange(of: contactEmail) { _, newValue in
            persistEmail(newValue)
        }
        .onChange(of: iCloudPDFSyncEnabled) { _, enabled in
            DocumentsUserSettings.isICloudPDFSyncEnabled = enabled
        }
    }

    private var connectionHint: String {
        if isConnected {
            return "Puoi sincronizzare i PDF HACCP dalla schermata Documenti."
        }
        if !hasICloudAccount {
            return "Accedi a iCloud sul dispositivo, poi torna qui e premi Verifica."
        }
        return "Serve l’Apple Developer Program per iCloud. I PDF restano sul dispositivo."
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EMAIL DI RIFERIMENTO")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                .tracking(1)
            TextField("nome@icloud.com", text: $contactEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(ThemeManager.shared.colorDivider.opacity(0.5))
                .cornerRadius(10)
                .disabled(activeRestaurant == nil)
            Text("Usa la stessa email dell'account iCloud del dispositivo.")
                .font(.caption2)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            if let emailValidationMessage {
                Label(emailValidationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func loadContactEmail() {
        guard let restaurant = activeRestaurant else {
            contactEmail = ""
            return
        }
        contactEmail = DocumentsUserSettings.iCloudContactEmail(
            restaurantId: restaurant.id,
            restaurantEmailFallback: restaurant.email
        )
    }

    private func persistEmail(_ newValue: String) {
        guard let rid = appState.activeRestaurantId else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            emailValidationMessage = nil
            return
        }
        if EmailValidator.isValid(trimmed) {
            DocumentsUserSettings.setICloudContactEmail(trimmed, restaurantId: rid)
            if let restaurant = activeRestaurant {
                restaurant.email = EmailValidator.normalized(trimmed)
                try? modelContext.save()
            }
            emailValidationMessage = nil
        } else {
            emailValidationMessage = "Formato email non valido."
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func verifyConnection() async {
        isVerifying = true
        _ = await iCloudSync.resolveUbiquityContainerURL()
        try? await Task.sleep(nanoseconds: 200_000_000)
        isVerifying = false
    }
}
