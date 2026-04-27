import SwiftUI

struct MasterFirstAccessIntroView: View {
    var onComplete: () -> Void
    
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
                        .frame(width: CGFloat(i * 60), height: CGFloat(i * 60))
                        .rotationEffect(.degrees(rotation + Double(i * 30)))
                        .opacity(0.3)
                }
                
                // Central Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.5), .orange.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .scaleEffect(scale)
            }
            
            VStack(spacing: 40) {
                if showText {
                    VStack(spacing: 24) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.yellow)
                            .shadow(color: .orange.opacity(0.6), radius: 30)
                            .transition(.scale.combined(with: .opacity))
                        
                        VStack(spacing: 8) {
                            Text("BENVENUTO, MASTER")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .yellow.opacity(0.5), radius: 10)
                            
                            Text("Configurazione Completata")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow.opacity(0.8))
                                .tracking(3)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        
                        Text("HACCP Manager ti aiuta a controllare utenti, procedure, temperature, etichette, pulizie e attività giornaliere del ristorante in modo semplice, sicuro e professionale.")
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .lineSpacing(6)
                            .padding(.horizontal, 80)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            onComplete()
                        }
                    }) {
                        Text("Inizia ora")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(.black)
                            .frame(maxWidth: 300)
                            .padding(.vertical, 20)
                            .background(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(20)
                            .shadow(color: .yellow.opacity(0.4), radius: 25, y: 10)
                    }
                    .padding(.top, 40)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.spring(response: 2.5, dampingFraction: 0.7).delay(0.5)) {
                scale = 1.3
                opacity = 1
            }
            withAnimation(.easeOut(duration: 1.2).delay(1.5)) {
                showText = true
            }
        }
    }
}
