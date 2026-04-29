import SwiftUI
import SwiftData
import Combine

public struct CreateRestaurantOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var stores: [AppDataStore]
    @Query private var users: [LocalUser]
    public var onComplete: () -> Void
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var manager: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var notes: String = ""
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    
    @State private var showError = false
    
    public var body: some View {
        ZStack {
            ThemeManager.shared.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                            .padding(.bottom, 10)
                            .shadow(color: .red.opacity(0.3), radius: 15)
                        
                        Text("Crea il tuo Ristorante")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(ThemeManager.shared.text)
                        
                        Text("Configura la tua attività principale per iniziare.")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    // Form
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            onboardingTextField(label: "Nome Ristorante*", text: $name, icon: "tray.full.fill")
                            onboardingTextField(label: "Indirizzo", text: $address, icon: "mappin.and.ellipse")
                            onboardingTextField(label: "Città", text: $city, icon: "building.2.fill")
                            onboardingTextField(label: "Responsabile HACCP*", text: $manager, icon: "person.badge.shield.check.fill")
                            
                            HStack(spacing: 20) {
                                onboardingTextField(label: "Telefono", text: $phone, icon: "phone.fill")
                                onboardingTextField(label: "Email", text: $email, icon: "envelope.fill")
                            }
                            
                            onboardingTextField(label: "Note", text: $notes, icon: "note.text")
                            securePinField(label: "PIN Ristorante (4 cifre)*", text: $pin, icon: "lock.fill")
                            securePinField(label: "Conferma PIN Ristorante*", text: $confirmPin, icon: "lock.shield.fill")
                        }
                        .padding(32)
                        .background(ThemeManager.shared.surface)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.1), radius: 20)
                    }
                    .frame(maxWidth: 700)
                    .transition(.scale.combined(with: .opacity))
                    
                    if showError {
                        Text("Nome, Responsabile e PIN ristorante (4 cifre) sono obbligatori.")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                            .transition(.opacity)
                    }
                    
                    Button(action: createRestaurant) {
                        Text("Conferma e Inizia")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding(.vertical, 20)
                            .background(formInvalid ? Color.gray : Color.red)
                            .cornerRadius(20)
                            .shadow(color: (name.isEmpty || manager.isEmpty ? Color.clear : Color.red.opacity(0.3)), radius: 20, y: 10)
                    }
                    .disabled(formInvalid)
                    .padding(.bottom, 60)
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showError)
    }
    
    private func onboardingTextField(label: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.red)
                TextField("", text: text)
                    .foregroundColor(ThemeManager.shared.text)
            }
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func securePinField(label: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.red)
                SecureField("0000", text: text)
                    .keyboardType(.numberPad)
                    .foregroundColor(ThemeManager.shared.text)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        text.wrappedValue = String(digits.prefix(4))
                    }
            }
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var formInvalid: Bool {
        name.isEmpty || manager.isEmpty || pin.count != 4 || pin != confirmPin
    }
    
    private func createRestaurant() {
        guard !name.isEmpty && !manager.isEmpty && pin.count == 4 && pin == confirmPin else {
            showError = true
            return
        }
        
        let newRestaurant = Restaurant(
            name: name,
            address: address,
            city: city,
            haccpManager: manager,
            phone: phone,
            email: email,
            notes: notes,
            restaurantPinHash: PinHasher.hash(pin: pin)
        )
        
        modelContext.insert(newRestaurant)
        
        // Set as active in AppDataStore
        if let store = stores.first {
            store.activeRestaurantId = newRestaurant.id
        }

        if let seededUser = users.first(where: { $0.id == appState.currentUserId }) ?? users.first(where: { $0.role == .master }) {
            try? ChecklistService().seedDefaultTemplatesIfNeeded(
                restaurantId: newRestaurant.id,
                createdBy: seededUser,
                modelContext: modelContext
            )
        }
        
        try? modelContext.save()
        onComplete()
    }
}
