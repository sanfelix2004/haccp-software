import SwiftUI
import SwiftData

struct MasterCreationSuccessView: View {
    @EnvironmentObject var appState: AppState
    @Query(filter: #Predicate<LocalUser> { $0.roleRaw == "MASTER" }) private var masters: [LocalUser]
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var showText = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Golden Vortex Background
            ZStack {
                ForEach(0..<12) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange, .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: CGFloat(i * 50), height: CGFloat(i * 50))
                        .rotationEffect(.degrees(rotation + Double(i * 30)))
                        .opacity(0.3)
                }
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.5), .orange.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .scaleEffect(scale)
            }
            
            VStack(spacing: 40) {
                if showText {
                    VStack(spacing: 20) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange, radius: 20)
                            .transition(.scale.combined(with: .opacity))
                        
                        Text("Benvenuto, MASTER")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .yellow.opacity(0.5), radius: 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        
                        Text("HACCP Manager ti aiuta a controllare utenti, procedure, temperature, etichette, pulizie e attività giornaliere del ristorante in modo semplice, sicuro e professionale.")
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 60)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Button(action: {
                        if let master = masters.first {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                appState.login(userId: master.id)
                            }
                        }
                    }) {
                        Text("Inizia")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: 200)
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(15)
                            .shadow(color: .yellow.opacity(0.4), radius: 20)
                    }
                    .padding(.top, 20)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.spring(response: 2, dampingFraction: 0.6).delay(0.5)) {
                scale = 1.2
                opacity = 1
            }
            withAnimation(.easeIn(duration: 1).delay(1.5)) {
                showText = true
            }
        }
    }
}
