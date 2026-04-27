import SwiftUI

struct DashboardEmptyStateView: View {
    let state: DashboardEmptyState
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.fill")
                .font(.system(size: 28))
                .foregroundColor(Color.white.opacity(0.7))
            Text(state.title)
                .font(.headline)
                .foregroundColor(.white)
            Text(state.message)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
            if let actionTitle = state.actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.9))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
