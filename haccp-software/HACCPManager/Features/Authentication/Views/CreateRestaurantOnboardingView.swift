import SwiftUI
import SwiftData

public struct CreateRestaurantOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stores: [AppDataStore]
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
                        }
                        .padding(32)
                        .background(ThemeManager.shared.surface)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.1), radius: 20)
                    }
                    .frame(maxWidth: 700)
                    .transition(.scale.combined(with: .opacity))
                    
                    if showError {
                        Text("Nome e Responsabile sono obbligatori.")
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
                            .background(name.isEmpty || manager.isEmpty ? Color.gray : Color.red)
                            .cornerRadius(20)
                            .shadow(color: (name.isEmpty || manager.isEmpty ? Color.clear : Color.red.opacity(0.3)), radius: 20, y: 10)
                    }
                    .disabled(name.isEmpty || manager.isEmpty)
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
    
    private func createRestaurant() {
        guard !name.isEmpty && !manager.isEmpty else {
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
            notes: notes
        )
        
        modelContext.insert(newRestaurant)
        
        // Set as active in AppDataStore
        if let store = stores.first {
            store.activeRestaurantId = newRestaurant.id
        }
        
        try? modelContext.save()
        onComplete()
    }
}
