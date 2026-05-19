import SwiftUI

struct AnalyticsEmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            Text(title)
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                .font(.headline)
            Text(message)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(12)
    }
}
