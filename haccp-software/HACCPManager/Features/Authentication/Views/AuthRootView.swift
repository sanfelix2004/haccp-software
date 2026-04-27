import SwiftUI
import SwiftData

struct AuthRootView: View {
    @Query private var users: [LocalUser]
    
    var body: some View {
        ZStack {
            ThemeManager.shared.background.ignoresSafeArea()
            
            if users.isEmpty {
                CreateMasterAccountView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                UserPickerLoginView(users: users)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: users.isEmpty)
    }
}
