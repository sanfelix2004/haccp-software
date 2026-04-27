import SwiftUI
import SwiftData

struct CreateUserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var role: UserRole = .haccpOperator
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var avatarColor = "#E63946"
    
    // Optional fields
    @State private var dateOfBirth: Date = Date()
    @State private var hasDateOfBirth = false
    @State private var notes = ""
    
    @State private var errorMessage: String?
    
    let colors = ["#E63946", "#1D3557", "#457B9D", "#2A9D8F", "#E9C46A", "#8338EC", "#FF006E", "#3A86FF"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Refined compact header
                    HStack(spacing: 24) {
                        // Compact Badge Preview
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: avatarColor), Color(hex: avatarColor).opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)
                                .shadow(color: Color(hex: avatarColor).opacity(0.4), radius: 15)
                            
                            Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .black))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "NOME COLLABORATORE" : name.uppercased())
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(role.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(32)
                    .background(Color.white.opacity(0.03))
                    
                    ScrollView {
                        VStack(spacing: 40) {
                            // Section: Basic Info
                            VStack(alignment: .leading, spacing: 20) {
                                Label("DATI PUBBLICI", systemImage: "person.text.rectangle")
                                    .font(.caption).fontWeight(.black).foregroundColor(.red).tracking(1)
                                
                                TextField("Nome Utente", text: $name)
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .colorScheme(.dark)
                                    .padding(.vertical, 18)
                                    .padding(.horizontal, 24)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("RUOLO AZIENDALE")
                                        .font(.caption2).fontWeight(.bold).foregroundColor(.gray)
                                    
                                    Picker("Ruolo", selection: $role) {
                                        ForEach(UserRole.allCases.filter { $0 != .master }, id: \.self) { r in
                                            Text(r.rawValue).tag(r)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Section: Optional Info
                            VStack(alignment: .leading, spacing: 20) {
                                Label("DETTAGLI AGGIUNTIVI", systemImage: "plus.circle")
                                    .font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(1)
                                
                                VStack(spacing: 1) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.red)
                                        Toggle("Data di nascita", isOn: $hasDateOfBirth)
                                            .tint(.red)
                                            .foregroundColor(.white)
                                    }
                                    .padding(20)
                                    .background(Color.white.opacity(0.05))
                                    
                                    if hasDateOfBirth {
                                        DatePicker("Seleziona data", selection: $dateOfBirth, displayedComponents: .date)
                                            .padding(20)
                                            .background(Color.white.opacity(0.05))
                                            .foregroundColor(.white)
                                            .colorScheme(.dark)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                    
                                    TextField("Note / Ruolo specifico / Squadra", text: $notes)
                                        .foregroundColor(.white)
                                        .padding(20)
                                        .background(Color.white.opacity(0.05))
                                }
                                .cornerRadius(16)
                                .clipped()
                            }
                            
                            // Color Selector
                            VStack(alignment: .leading, spacing: 16) {
                                Text("COLORE IDENTIFICATIVO")
                                    .font(.caption2).fontWeight(.bold).foregroundColor(.gray)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(colors, id: \.self) { hex in
                                            Circle()
                                                .fill(Color(hex: hex))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle().stroke(Color.white, lineWidth: avatarColor == hex ? 3 : 0)
                                                )
                                                .shadow(color: Color(hex: hex).opacity(0.3), radius: 8)
                                                .onTapGesture { 
                                                    withAnimation(.spring()) { avatarColor = hex }
                                                }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            
                            NavigationLink {
                                SetNewUserPinView(
                                    name: name,
                                    role: role,
                                    avatarColorHex: avatarColor,
                                    dateOfBirth: hasDateOfBirth ? dateOfBirth : nil,
                                    notes: notes.isEmpty ? nil : notes
                                )
                            } label: {
                                HStack {
                                    Text("Prossimo: Configurazione PIN")
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(name.isEmpty ? Color.gray.opacity(0.3) : Color.red)
                                .foregroundColor(name.isEmpty ? .white.opacity(0.5) : .white)
                                .cornerRadius(16)
                                .shadow(color: name.isEmpty ? .clear : .red.opacity(0.3), radius: 15)
                            }
                            .disabled(name.isEmpty)
                        }
                        .padding(40)
                    }
                    .background(Color(hex: "#0A0A0A"))
                }
            }
            .navigationTitle("Anagrafica Personale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// Extension to support partial corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
