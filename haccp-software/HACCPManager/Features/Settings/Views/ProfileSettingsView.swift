import SwiftUI
import PhotosUI
import SwiftData

struct ProfileSettingsView: View {
    let user: LocalUser?
    var storage = SettingsStorageService.shared
    @EnvironmentObject var appState: AppState
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showingPinChange = false
    @State private var showingNameEdit = false
    @State private var editedName = ""
    
    var body: some View {
        VStack(spacing: 24) {
            if let user = user {
                // Header Profile
                VStack(spacing: 20) {
                    ZStack {
                        if let data = user.profileImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
                        } else {
                            Circle()
                                .fill(Color(hex: user.avatarColorHex))
                                .frame(width: 110, height: 110)
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
                                .overlay(
                                    Text(String(user.name.prefix(1)).uppercased())
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                )
                        }
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Circle()
                                .fill(ThemeManager.shared.colorScrim)
                                .frame(width: 36, height: 36)
                                .overlay(Image(systemName: "camera.fill").font(.caption).foregroundStyle(ThemeManager.shared.colorTextPrimary))
                        }
                        .offset(x: 38, y: 38)
                    }
                    
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(user.name)
                                .font(.title2.weight(.bold))
                            Button(action: {
                                editedName = user.name
                                showingNameEdit = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Text(user.role.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                SettingsPanelCard(title: "Dettagli") {
                    VStack(alignment: .leading, spacing: 0) {
                        StaticSettingRow(title: "Ruolo", value: user.role.rawValue, icon: "shield.fill")
                        
                        if user.role == .master {
                            Divider().background(ThemeManager.shared.colorDivider)
                            EditableSettingRow(title: "Email", value: user.email ?? "Non configurata") {
                                tempValue = user.email ?? ""
                                editField = .email
                                showingDetailEdit = true
                            }
                            Divider().background(ThemeManager.shared.colorDivider)
                            EditableSettingRow(title: "Telefono", value: user.phoneNumber ?? "Non configurato") {
                                tempValue = user.phoneNumber ?? ""
                                editField = .phone
                                showingDetailEdit = true
                            }
                        }
                    }
                }

                ProfileICloudConnectionSection()
                
                VStack(spacing: 12) {
                    Button(action: { showingPinChange = true }) {
                        Label("Modifica PIN", systemImage: "key.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ThemeManager.shared.colorDivider)
                            .cornerRadius(14)
                    }
                    
                    Button(action: { appState.logout() }) {
                        Label("Esci", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(14)
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _ in
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                    user?.profileImageData = data
                    try? user?.modelContext?.save()
                }
            }
        }
        .sheet(isPresented: $showingNameEdit) {
            NameEditSheet(name: $editedName) {
                user?.name = editedName
                try? user?.modelContext?.save()
                showingNameEdit = false
            }
        }
        .sheet(isPresented: $showingPinChange) {
            PinChangeSheet(user: user)
        }
        .sheet(isPresented: $showingDetailEdit) {
            DetailEditSheet(value: $tempValue, field: editField) {
                switch editField {
                case .email: user?.email = tempValue.isEmpty ? nil : tempValue
                case .phone: user?.phoneNumber = tempValue.isEmpty ? nil : tempValue
                }
                try? user?.modelContext?.save()
                showingDetailEdit = false
            }
        }
    }
    
    @State private var showingDetailEdit = false
    @State private var tempValue = ""
    @State private var editField: EditField = .email
    
    enum EditField: String {
        case email = "Email"
        case phone = "Telefono"
    }
}

struct StaticSettingRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            }
            Spacer()
        }
        .padding(20)
    }
}

struct EditableSettingRow: View {
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundColor(.red)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.red)
                    Text(value)
                        .font(.body)
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorDivider)
            }
            .padding(20)
        }
        .buttonStyle(.plain)
    }
}

struct NameEditSheet: View {
    @Binding var name: String
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.colorBackground.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOME COLLABORATORE")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.red)
                            .padding(.leading, 12)
                        
                        TextField("Nome", text: $name)
                            .padding()
                            .background(ThemeManager.shared.colorDivider)
                            .cornerRadius(12)
                            .font(.title3)
                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    }
                    
                    Spacer()
                    
                    Button(action: onSave) {
                        Text("SALVA MODIFICHE")
                            .font(.headline)
                            .foregroundStyle(ThemeManager.shared.colorTextOnPrimary)
                            .padding()
                            .frame(maxWidth: .infinity).background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(30)
            }
            .navigationTitle("Modifica Nome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

struct PinChangeSheet: View {
    let user: LocalUser?
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var error: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.colorBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        SecureFieldRow(label: "PIN ATTUALE", text: $currentPin)
                        SecureFieldRow(label: "NUOVO PIN (4 CIFRE)", text: $newPin)
                        SecureFieldRow(label: "CONFERMA NUOVO PIN", text: $confirmPin)
                        
                        if let error = error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Spacer(minLength: 40)
                        
                        Button(action: savePin) {
                            Text("AGGIORNA PIN")
                                .font(.headline)
                                .foregroundStyle(ThemeManager.shared.colorTextOnPrimary)
                                .padding()
                                .frame(maxWidth: .infinity).background(Color.red)
                                .cornerRadius(12)
                        }
                        .disabled(newPin.count != 4 || newPin != confirmPin)
                    }
                    .padding(30)
                }
            }
            .navigationTitle("Cambio PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
    
    private func savePin() {
        guard let user = user else { return }
        
        let currentHash = PinHasher.hash(pin: currentPin)
        if currentHash != user.pinHash {
            error = "Il PIN attuale non è corretto."
            return
        }
        
        if newPin.count != 4 {
            error = "Il nuovo PIN deve essere di 4 cifre."
            return
        }
        
        if newPin != confirmPin {
            error = "I PIN non coincidono."
            return
        }
        
        user.pinHash = PinHasher.hash(pin: newPin)
        try? user.modelContext?.save()
        dismiss()
    }
}
struct DetailEditSheet: View {
    @Binding var value: String
    let field: ProfileSettingsView.EditField
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.colorBackground.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(field.rawValue.uppercased())
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.red)
                            .padding(.leading, 12)
                        
                        TextField(field.rawValue, text: $value)
                            .padding()
                            .background(ThemeManager.shared.colorDivider)
                            .cornerRadius(12)
                            .font(.title3)
                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                            .keyboardType(field == ProfileSettingsView.EditField.email ? .emailAddress : .phonePad)
                            .autocapitalization(.none)
                    }
                    
                    Spacer()
                    
                    Button(action: onSave) {
                        Text("AGGIORNA")
                            .font(.headline)
                            .foregroundStyle(ThemeManager.shared.colorTextOnPrimary)
                            .padding()
                            .frame(maxWidth: .infinity).background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(30)
            }
            .navigationTitle("Modifica \(field.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

struct SecureFieldRow: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.red)
                .padding(.leading, 12)
            
            SecureField("****", text: $text)
                .keyboardType(.numberPad)
                .padding()
                .background(ThemeManager.shared.colorDivider)
                .cornerRadius(12)
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                .onChange(of: text) { newValue in
                    if newValue.count > 4 {
                        text = String(newValue.prefix(4))
                    }
                }
        }
    }
}
