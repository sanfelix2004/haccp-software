import SwiftUI
import SwiftData

struct UserPickerLoginView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]
    let users: [LocalUser]
    
    @State private var selectedUser: LocalUser?
    @State private var selectedRestaurant: Restaurant?
    @State private var showCreateUser = false
    @State private var authMasterForAddUser: LocalUser?
    @State private var authMasterForReset: LocalUser?
    
    // iPad friendly grid
    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 30)
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color.black, Color(hex: "#1A0000")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                if selectedUser == nil {
                    // Header
                    VStack(spacing: 12) {
                        Text("HACCP Manager")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .red.opacity(0.3), radius: 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        
                        Text("Seleziona il tuo profilo professionale")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .tracking(2)
                            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                    }
                    .padding(.top, 60)
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 30) {
                            ForEach(users, id: \.id) { user in
                                UserPickerCell(user: user) {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        selectedUser = user
                                        selectedRestaurant = restaurants.count == 1 ? restaurants.first : nil
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.8))
                                ))
                            }
                            
                            // ADD USER BUTTON
                            AddUserCell {
                                if let master = users.first(where: { $0.role == .master }) {
                                    withAnimation(.spring()) { authMasterForAddUser = master }
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        .padding(40)
                    }
                } else if let user = selectedUser, selectedRestaurant == nil {
                    LoginRestaurantSelectionView(
                        selectedUser: user,
                        restaurants: restaurants,
                        onBack: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedUser = nil
                            }
                        },
                        onSelectRestaurant: { restaurant in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                selectedRestaurant = restaurant
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    RestaurantPinAccessView(
                        user: selectedUser!,
                        restaurant: selectedRestaurant!,
                        onCancel: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedRestaurant = nil
                            }
                        },
                        onSuccess: {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                appState.activeRestaurantId = selectedRestaurant!.id
                                appState.login(userId: selectedUser!.id)
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedUser == nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissCreateUserSheet"))) { _ in
                showCreateUser = false
            }
            
            // --- MASTER AUTH OVERLAY FOR NEW USER ---
            if let master = authMasterForAddUser {
                MasterAuthOverlay(
                    master: master,
                    operation: .createUser,
                    onAuthorized: {
                        authMasterForAddUser = nil
                        showCreateUser = true
                    },
                    onCancel: {
                        authMasterForAddUser = nil
                    }
                ) { EmptyView() }
                .zIndex(10)
            }
            
            if let master = authMasterForReset {
                MasterAuthOverlay(
                    master: master,
                    operation: .resetDatabase,
                    onAuthorized: {
                        authMasterForReset = nil
                        performResetDatabase()
                    },
                    onCancel: {
                        authMasterForReset = nil
                    }
                ) { EmptyView() }
                .zIndex(10)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: resetDatabase) {
                        Text("Reset completo app")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                    }
                    .padding(24)
                }
            }

        }
        .sheet(isPresented: $showCreateUser) {
            CreateUserView()
        }
    }

    private func resetDatabase() {
        guard let master = users.first(where: { $0.role == .master }) else { return }
        withAnimation(.spring()) {
            authMasterForReset = master
        }
    }

    private func performResetDatabase() {
        appState.factoryReset(modelContext: modelContext)
    }
}

struct LoginRestaurantSelectionView: View {
    let selectedUser: LocalUser
    let restaurants: [Restaurant]
    let onBack: () -> Void
    let onSelectRestaurant: (Restaurant) -> Void

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button(action: onBack) {
                    Label("Indietro", systemImage: "chevron.left")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                Text("Accesso ristorante")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Seleziona il ristorante per \(selectedUser.name)")
                    .foregroundColor(.gray)
            }

            if restaurants.count == 1, let onlyRestaurant = restaurants.first {
                RestaurantCard(restaurant: onlyRestaurant) {
                    onSelectRestaurant(onlyRestaurant)
                }
                .padding(.horizontal, 20)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 20)], spacing: 20) {
                        ForEach(restaurants) { restaurant in
                            RestaurantCard(restaurant: restaurant) {
                                onSelectRestaurant(restaurant)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(40)
    }
}

struct RestaurantPinAccessView: View {
    let user: LocalUser
    let restaurant: Restaurant
    let onCancel: () -> Void
    let onSuccess: () -> Void

    @State private var enteredPin = ""
    @State private var isError = false

    private let columns = [
        GridItem(.fixed(80)),
        GridItem(.fixed(80)),
        GridItem(.fixed(80))
    ]

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button(action: onCancel) {
                    Label("Ristoranti", systemImage: "chevron.left")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
                Spacer()
            }

            VStack(spacing: 14) {
                Text("Accesso a \(restaurant.name)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Inserisci il codice del ristorante per continuare")
                    .foregroundColor(.gray)
            }

            HStack(spacing: 16) {
                if let data = restaurant.logoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 74, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 74, height: 74)
                        .overlay(Image(systemName: "building.2.fill").foregroundColor(.red))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name).foregroundColor(.white).font(.headline)
                    Text(user.role.rawValue).foregroundColor(.gray).font(.subheadline)
                }
                Spacer()
                if user.role == .master {
                    Text("MASTER")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#FFD700"))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPin.count ? Color.red : Color.white.opacity(0.2))
                        .frame(width: 14, height: 14)
                }
            }
            .offset(x: isError ? -8 : 0)
            .animation(isError ? .default.repeatCount(3).speed(4) : .default, value: isError)
            
            if isError {
                Text("Codice ristorante non valido. Riprova.")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.red.opacity(0.9))
                    .transition(.opacity)
            }

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(1...9, id: \.self) { number in
                    keypadButton(text: "\(number)") { append("\(number)") }
                }
                keypadButton(text: "C") { clear() }
                keypadButton(text: "0") { append("0") }
                keypadButton(text: "⌫") { deleteLast() }
            }
            .padding(.top, 8)
        }
        .padding(40)
    }

    private func keypadButton(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 84, height: 84)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func append(_ value: String) {
        guard enteredPin.count < 4 else { return }
        HapticManager.shared.trigger(.light)
        enteredPin += value
        if enteredPin.count == 4 {
            verifyRestaurantPin()
        }
    }

    private func clear() {
        HapticManager.shared.trigger(.medium)
        enteredPin = ""
    }

    private func deleteLast() {
        guard !enteredPin.isEmpty else { return }
        HapticManager.shared.trigger(.light)
        enteredPin.removeLast()
    }

    private func verifyRestaurantPin() {
        let isValid = PinHasher.hash(pin: enteredPin) == restaurant.restaurantPinHash
        if isValid {
            SecurityService.shared.reportSuccessfulLogin()
            onSuccess()
            return
        }

        SecurityService.shared.reportFailedAttempt()
        isError = true
        enteredPin = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isError = false
        }
    }
}

struct UserPickerCell: View {
    let user: LocalUser
    var action: () -> Void
    
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background Glow for Master
                if user.role == .master {
                    Circle()
                        .fill(Color(hex: "#FFD700").opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 25)
                }
                
                // Animated Border for Master
                if user.role == .master {
                    Circle()
                        .stroke(
                            LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500"), Color(hex: "#B8860B"), Color(hex: "#FFD700")], 
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 4
                        )
                        .frame(width: 114, height: 114)
                        .rotationEffect(.degrees(rotation))
                }
                
                ZStack {
                    if let data = user.profileImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(hex: user.avatarColorHex))
                            .frame(width: 100, height: 100)
                        
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: Color.black.opacity(0.4), radius: 12, y: 8)
                
                if user.role == .master {
                    SparkleView()
                        .offset(x: -45, y: -45)
                    SparkleView()
                        .offset(x: 45, y: 35)
                }
            }
            
            VStack(spacing: 6) {
                Text(user.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if user.role == .master {
                    Text("MASTER")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(6)
                        .foregroundColor(.black)
                } else {
                    Text(user.role.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.gray)
                        .tracking(1.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(user.role == .master ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                .shadow(color: .black.opacity(0.2), radius: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(user.role == .master ? Color(hex: "#FFD700").opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .onAppear {
            if user.role == .master {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
        .onTapGesture {
            action()
        }
    }
}

struct SparkleView: View {
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.4
    
    var body: some View {
        Image(systemName: "sparkle")
            .foregroundColor(Color(hex: "#FFD700"))
            .font(.system(size: 16))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 1.2...2.0)).repeatForever(autoreverses: true)) {
                    scale = 1.3
                    opacity = 1.0
                }
            }
    }
}

struct AddUserCell: View {
    var action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "plus")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundColor(.gray.opacity(0.4))
            }
            
            Text("Aggiungi")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.02))
        )
        .onTapGesture {
            action()
        }
    }
}
