import SwiftUI

struct LoadingOverlay: View {
    let message: String
    
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated Logo / Loader
                ZStack {
                    // Outer spinning ring
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.red, .clear, .red.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 4
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotation))
                    
                    // Inner pulsing logo
                    Image(systemName: "house.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .scaleEffect(pulse)
                }
                
                VStack(spacing: 8) {
                    Text(message.uppercased())
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .tracking(4)
                    
                    Text("Configurazione in corso...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = 1.2
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 1.1)))
    }
}

#Preview {
    LoadingOverlay(message: "Cambio Ristorante")
}
