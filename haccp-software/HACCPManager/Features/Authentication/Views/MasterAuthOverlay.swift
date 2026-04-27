import SwiftUI

struct MasterAuthOverlay<Content: View>: View {
    let master: LocalUser
    let operation: MasterAuthorizationService.Operation
    let onAuthorized: () -> Void
    let onCancel: () -> Void
    
    @ViewBuilder var content: Content
    
    @State private var biometricType: BiometricAuthManager.BiometricType = .none
    @State private var biometricFailed = false
    
    var body: some View {
        ZStack {
            // Full Screen Background (Solid Black for max depth)
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                PinLoginView(
                    user: master,
                    onCancel: { withAnimation(.spring()) { onCancel() } },
                    onSuccess: {
                        withAnimation(.spring()) { onAuthorized() }
                    },
                    isCompact: false
                )
                
                // Subtle Operation Reason
                Text(operation.localizedReason.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white.opacity(0.2))
                    .tracking(3)
                    .padding(.top, 40)
                
                Spacer()
            }
        }
        .transition(.opacity)
        .zIndex(2000)
    }
}
