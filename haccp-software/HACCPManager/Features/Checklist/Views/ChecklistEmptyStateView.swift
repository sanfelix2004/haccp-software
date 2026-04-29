import SwiftUI

struct ChecklistEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 44))
                .foregroundColor(.red.opacity(0.9))
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
    }
}
