import SwiftUI

struct AnalyticsEmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundColor(.gray)
            Text(title)
                .foregroundColor(.white)
                .font(.headline)
            Text(message)
                .foregroundColor(.gray)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}
