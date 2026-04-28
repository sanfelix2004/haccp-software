import SwiftUI
import SwiftData
import PhotosUI

struct RestaurantSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var restaurants: [Restaurant]
    @Query private var users: [LocalUser]
    @Query private var stores: [AppDataStore]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var restaurantToEdit: Restaurant?
    @State private var showingDeleteConfirmation = false
    @State private var restaurantToDelete: Restaurant?
    
    // For Photo Picking
    @State private var logoItem: PhotosPickerItem?
    @State private var selectedLogoData: Data?
    
    var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }
    
    var activeRestaurant: Restaurant? {
        if let activeId = appState.activeRestaurantId {
            return restaurants.first { $0.id == activeId }
        }
        return restaurants.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                Text("Gestione Ristoranti")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if currentUser?.role == .master && restaurants.isEmpty {
                    Button(action: { showingAddSheet = true }) {
                        Label("Aggiungi Locale", systemImage: "plus.circle.fill")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
            }
            
            if restaurants.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "house.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Nessun ristorante configurato.")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Text("Modalita singolo ristorante attiva: e consentita una sola scheda ristorante su questo iPad.")
                    .font(.caption)
                    .foregroundColor(.gray)

                LazyVStack(spacing: 16) {
                    ForEach(restaurants) { restaurant in
                        restaurantRow(restaurant)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RestaurantEditSheet(restaurant: nil)
        }
        .sheet(item: $restaurantToEdit) { restaurant in
            RestaurantEditSheet(restaurant: restaurant)
        }
        .alert("Elimina Ristorante", isPresented: $showingDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let restaurant = restaurantToDelete {
                    deleteRestaurant(restaurant)
                }
            }
        } message: {
            Text("Sei sicuro di voler eliminare '\(restaurantToDelete?.name ?? "")'? Questa operazione non è reversibile.")
        }
    }
    
    private func restaurantRow(_ restaurant: Restaurant) -> some View {
        let isActive = restaurant.id == activeRestaurant?.id
        
        return HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(restaurant.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isActive {
                        Text("ATTIVO")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                Text("\(restaurant.city), \(restaurant.address)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("Resp: \(restaurant.haccpManager)")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            
            Spacer()
            
            if !isActive {
                Button("Seleziona") {
                    selectRestaurant(restaurant)
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            if currentUser?.role == .master {
                HStack(spacing: 15) {
                    Button(action: { restaurantToEdit = restaurant }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        restaurantToDelete = restaurant
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .disabled(restaurants.count <= 1) // Must have at least one
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
    
    private func selectRestaurant(_ restaurant: Restaurant) {
        appState.switchRestaurant(id: restaurant.id, modelContext: modelContext)
    }
    
    private func deleteRestaurant(_ restaurant: Restaurant) {
        let isActive = restaurant.id == activeRestaurant?.id
        modelContext.delete(restaurant)
        
        if isActive && restaurants.count > 1 {
            // Select another one
            if let next = restaurants.first(where: { $0.id != restaurant.id }) {
                selectRestaurant(next)
            }
        }
        
        try? modelContext.save()
    }
}

struct RestaurantEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Query private var stores: [AppDataStore]
    
    let restaurant: Restaurant?
    
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var manager: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var notes: String = ""
    @State private var newRestaurantPin: String = ""
    @State private var confirmRestaurantPin: String = ""
    @State private var logoItem: PhotosPickerItem?
    @State private var logoData: Data?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0F0F0F").ignoresSafeArea()
                
                Form {
                    Section("Branding") {
                        HStack(spacing: 20) {
                            if let data = logoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 100, height: 100)
                                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
                            }
                            
                            PhotosPicker(selection: $logoItem, matching: .images) {
                                Label("Scegli Logo", systemImage: "photo.badge.plus")
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            .onChange(of: logoItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        logoData = data
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    
                    Section("Dati Identificativi") {
                        TextField("Nome Ristorante*", text: $name)
                        TextField("Responsabile HACCP*", text: $manager)
                    }
                    
                    Section("Localizzazione") {
                        TextField("Indirizzo", text: $address)
                        TextField("Città", text: $city)
                    }
                    
                    Section("Contatti") {
                        TextField("Telefono", text: $phone)
                        TextField("Email", text: $email)
                    }
                    
                    Section("Altro") {
                        TextField("Note", text: $notes, axis: .vertical)
                            .lineLimit(3...10)
                    }

                    Section("Sicurezza Ristorante") {
                        SecureField("Nuovo PIN Ristorante (4 cifre)", text: $newRestaurantPin)
                            .keyboardType(.numberPad)
                            .onChange(of: newRestaurantPin) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                newRestaurantPin = String(digits.prefix(4))
                            }
                        SecureField("Conferma Nuovo PIN", text: $confirmRestaurantPin)
                            .keyboardType(.numberPad)
                            .onChange(of: confirmRestaurantPin) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                confirmRestaurantPin = String(digits.prefix(4))
                            }
                        Text("Il PIN ristorante viene salvato in forma hashata.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle(restaurant == nil ? "Nuovo Ristorante" : "Modifica Ristorante")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") { save() }
                            .disabled(name.isEmpty || manager.isEmpty || !isPinSectionValid)
                    }
                }
            }
        }
        .onAppear {
            if let r = restaurant {
                name = r.name
                address = r.address
                city = r.city
                manager = r.haccpManager
                phone = r.phone
                email = r.email
                notes = r.notes
                logoData = r.logoData
            }
        }
    }
    
    private func save() {
        if let r = restaurant {
            r.name = name
            r.address = address
            r.city = city
            r.haccpManager = manager
            r.phone = phone
            r.email = email
            r.notes = notes
            r.logoData = logoData
            if !newRestaurantPin.isEmpty {
                r.restaurantPinHash = PinHasher.hash(pin: newRestaurantPin)
            }
        } else {
            guard !hasExistingRestaurant else {
                dismiss()
                return
            }
            let new = Restaurant(
                name: name,
                address: address,
                city: city,
                haccpManager: manager,
                phone: phone,
                email: email,
                notes: notes,
                restaurantPinHash: PinHasher.hash(pin: newRestaurantPin),
                logoData: logoData
            )
            modelContext.insert(new)
            
            // If it's the first one, make it active
            if store?.activeRestaurantId == nil {
                store?.activeRestaurantId = new.id
                appState.activeRestaurantId = new.id
            }
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private var store: AppDataStore? {
        stores.first
    }

    private var isPinSectionValid: Bool {
        if restaurant == nil {
            return newRestaurantPin.count == 4 && confirmRestaurantPin == newRestaurantPin
        }
        if newRestaurantPin.isEmpty && confirmRestaurantPin.isEmpty {
            return true
        }
        return newRestaurantPin.count == 4 && confirmRestaurantPin == newRestaurantPin
    }

    private var hasExistingRestaurant: Bool {
        let descriptor = FetchDescriptor<Restaurant>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        return !existing.isEmpty
    }
}
