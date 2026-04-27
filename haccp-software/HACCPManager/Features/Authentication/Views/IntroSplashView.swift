import SwiftUI

struct IntroSplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var isActive: Bool = false
    @State private var size = 0.8
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Elegant background
            LinearGradient(
                colors: [Color.black, Color(hex: "#1A0000")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Main Logo / Title
                Text(AppVersionService.appName)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#E63946"))
                    .shadow(color: Color(hex: "#E63946").opacity(isActive ? 0.6 : 0.0), radius: 30, x: 0, y: 0)
                    .offset(y: isActive ? 0 : 20)
                
                // Subtitle
                Text("DIGITAL FOOD SAFETY CONTROL")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(8)
                    .padding(.top, 40)
                    .opacity(isActive ? 1 : 0)
            }
            .scaleEffect(size)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                    self.size = 1.0
                    self.opacity = 1.0
                    self.isActive = true
                }
                
                // End Splash after 2.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        self.size = 1.1
                        self.opacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring()) {
                            appState.showSplash = false
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
