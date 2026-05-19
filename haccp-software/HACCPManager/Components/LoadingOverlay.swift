import SwiftUI

struct LoadingOverlay: View {
    let message: String

    @Environment(\.theme) private var theme
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Rectangle()
                .fill(theme.colorScrim)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [theme.colorPrimary, .clear, theme.colorPrimary.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotation))

                    Image(systemName: "house.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.colorPrimary)
                        .scaleEffect(pulse)
                }

                VStack(spacing: 8) {
                    Text(message.uppercased())
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(theme.colorTextPrimary)
                        .tracking(4)

                    Text("Configurazione in corso...")
                        .font(.caption)
                        .foregroundStyle(theme.colorTextSecondary)
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
